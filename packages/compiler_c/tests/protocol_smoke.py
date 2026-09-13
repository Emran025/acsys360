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
    assert read.returncode == 0, read.stderr
    assert read_response["success"] is True

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
