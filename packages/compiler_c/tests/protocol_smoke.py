#!/usr/bin/env python3
import json
import subprocess
import sys


def run(executable, source, target=None):
    request = {
        "protocolVersion": "0.5.0",
        "rootPath": ".",
        "sourcePaths": ["main.arb"],
        "sourceTexts": {"main.arb": source},
        "mode": "project",
        "entryPath": "main.arb",
    }
    if target:
        request["target"] = target
    completed = subprocess.run(
        [executable, "--protocol"],
        input=json.dumps(request, ensure_ascii=False),
        text=True,
        encoding="utf-8",
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
        encoding="utf-8",
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
        encoding="utf-8",
    )
    session.stdin.write(json.dumps(interactive_request, ensure_ascii=False) + "\n")
    session.stdin.flush()
    first_input = json.loads(session.stdout.readline())
    assert first_input == {
        "requestType": "input",
        "name": "س",
        "type": "صحيح",
    }
    session.stdin.write(json.dumps({"value": "11"}) + "\n")
    session.stdin.flush()
    second_input = json.loads(session.stdout.readline())
    assert second_input == {
        "requestType": "input",
        "name": "ص",
        "type": "صحيح",
    }
    session.stdin.write(json.dumps({"value": "22"}) + "\n")
    session.stdin.flush()
    final_response = json.loads(session.stdout.readline())
    assert final_response["executionOutput"] == ["11", "22"]
    session.stdin.close()
    assert session.wait(timeout=5) == 0

    mismatch, mismatch_response = run(
        executable,
        "برنامج أنواع؛ متغير رقم: صحيح؛ متغير نص: خيط_رمزي؛ "
        "{ رقم = نص؛ }.",
    )
    assert mismatch.returncode != 0
    assert mismatch_response["success"] is False
    assert any(
        item["phase"] == "semantic" and "عدم توافق نوع الإسناد" in item["message"]
        for item in mismatch_response["diagnostics"]
    )

    native_type, native_type_response = run(
        executable,
        "برنامج أصلي؛\n"
        "متغير سعر: حقيقي؛\n"
        "{\n"
        "  سعر = 2.5؛\n"
        "}.\n",
        target="dart-native",
    )
    assert native_type.returncode == 0
    assert native_type_response["success"] is True
    assert "movsd" in native_type_response["assembly"]
    assert "fmt_real" in native_type_response["assembly"]

    native_text, native_text_response = run(
        executable,
        "برنامج نصوص؛\n"
        "ثابت رسالة = \"مرحبا\"؛\n"
        "ثابت حرف_اول = ’أ‘؛\n"
        "متغير نص: خيط_رمزي؛ متغير رمز: حرفي؛\n"
        "{ نص = رسالة؛ رمز = حرف_اول؛ اطبع(نص, رمز)؛ }.\n",
        target="dart-native",
    )
    assert native_text.returncode == 0
    assert native_text_response["success"] is True
    assert "text0:" in native_text_response["assembly"]
    assert "fmt_str" in native_text_response["assembly"]

    full_native, full_native_response = run(
        executable,
        """برنامج اساسيات؛
ثابت س = 7؛
ثابت رسالة = "مرحبا"؛
ثابت حرف_اول = ’أ‘؛
ثابت حالة = صح؛
متغير عمر, عداد: صحيح؛
متغير سعر: حقيقي؛
متغير نشط: منطقي؛
متغير رمز: حرفي؛
متغير نص: خيط_رمزي؛
{
  عمر = س؛
  عداد = عمر + 3؛
  سعر = 2.5؛
  نشط = حالة؛
  رمز = حرف_اول؛
  نص = رسالة؛
  اطبع(عمر, عداد, سعر, نشط, رمز, نص)؛
}.
""",
        target="dart-native",
    )
    assert full_native.returncode == 0, full_native.stderr
    assert full_native_response["success"] is True

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
