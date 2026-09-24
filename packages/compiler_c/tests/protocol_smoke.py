#!/usr/bin/env python3
import json
import subprocess
import sys


def run(executable, source):
    request = {
        "protocolVersion": "0.5.0",
        "rootPath": ".",
        "sourcePaths": ["main.arb"],
        "sourceTexts": {"main.arb": source},
        "mode": "project",
        "entryPath": "main.arb",
    }
    completed = subprocess.run(
        [executable, "--protocol"],
        input=json.dumps(request),
        text=True,
        capture_output=True,
        check=False,
    )
    return completed, json.loads(completed.stdout)


def main():
    executable = sys.argv[1]
    valid, valid_response = run(
        executable,
        "برنامج اختبار؛ متغير س: صحيح؛ { س = 42؛ اطبع(س)؛ }.",
    )
    assert valid.returncode == 0, valid.stderr
    assert valid_response["success"] is True
    assert valid_response["tokens"]
    assert valid_response["syntaxTree"]["kind"] == "program"
    assert valid_response["symbolTable"][0]["name"] == "س"

    power, power_response = run(
        executable,
        "برنامج قوة؛ { اطبع(2 ^ 3)؛ اطبع(9 ^ 0.5)؛ }.",
    )
    assert power.returncode == 0, power.stderr
    assert power_response["success"] is True
    assert power_response["executionOutput"] == ["8", "3"]
    read, read_response = run(
        executable,
        "برنامج قراءة؛ متغير س: صحيح؛ { اقرأ(س)؛ اطبع(س)؛ }.",
    )
    assert read.returncode != 0, read.stderr
    assert read_response["success"] is False
    assert any(item["code"] == "R001" for item in read_response["diagnostics"])

    read_request = {
        "protocolVersion": "0.5.0",
        "rootPath": ".",
        "sourcePaths": ["main.arb"],
        "sourceTexts": {
            "main.arb": "برنامج قراءة؛ متغير س: صحيح؛ { اقرأ(س)؛ اطبع(س)؛ }."
        },
        "mode": "active",
        "entryPath": "main.arb",
        "inputValues": {"س": "42"},
    }
    completed = subprocess.run(
        [executable, "--protocol"],
        input=json.dumps(read_request, ensure_ascii=False),
        text=True,
        capture_output=True,
        check=False,
    )
    assert completed.returncode == 0, completed.stderr
    assert json.loads(completed.stdout)["executionOutput"] == ["42"]

    analysis_request = dict(read_request)
    analysis_request["execute"] = False
    analysis = subprocess.run(
        [executable, "--protocol"],
        input=json.dumps(analysis_request, ensure_ascii=False),
        text=True,
        capture_output=True,
        check=False,
    )
    assert analysis.returncode == 0, analysis.stderr
    assert json.loads(analysis.stdout)["executionOutput"] == []

    interactive_request = dict(read_request)
    interactive_request["sourceTexts"] = {
        "main.arb": (
            "برنامج قراءة؛ متغير س: صحيح؛ متغير ص: صحيح؛ "
            "{ اقرأ(س)؛ اقرأ(ص)؛ اطبع(س)؛ اطبع(ص)؛ }."
        )
    }
    interactive_request["inputValues"] = {}
    interactive_request["interactive"] = True
    session = subprocess.Popen(
        [executable, "--protocol"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    session.stdin.write(json.dumps(interactive_request, ensure_ascii=False) + "\n")
    session.stdin.flush()
    first_input = json.loads(session.stdout.readline())
    assert first_input == {"requestType": "input", "name": "س"}
    session.stdin.write(json.dumps({"value": "11"}) + "\n")
    session.stdin.flush()
    second_input = json.loads(session.stdout.readline())
    assert second_input == {"requestType": "input", "name": "ص"}
    session.stdin.write(json.dumps({"value": "22"}) + "\n")
    session.stdin.flush()
    final_response = json.loads(session.stdout.readline())
    assert final_response["executionOutput"] == ["11", "22"]
    session.stdin.close()
    assert session.wait(timeout=5) == 0

    invalid, invalid_response = run(
        executable,
        "برنامج اختبار؛ متغير س: صحيح؛ { اطبع(مفقود)؛ }.",
    )
    assert invalid.returncode != 0
    assert invalid_response["success"] is False
    diagnostic = invalid_response["diagnostics"][0]
    assert diagnostic["phase"] == "semantic"
    assert diagnostic["span"]["sourcePath"] == "main.arb"
    assert diagnostic["span"]["line"] >= 1
    assert diagnostic["span"]["column"] >= 1

    syntax, syntax_response = run(
        executable,
        "برنامج اختبار؛ متغير س: صحيح؛ { س = ؛ }.",
    )
    assert syntax.returncode != 0
    assert syntax_response["success"] is False
    assert syntax_response["diagnostics"][0]["phase"] == "syntax"


if __name__ == "__main__":
    main()
