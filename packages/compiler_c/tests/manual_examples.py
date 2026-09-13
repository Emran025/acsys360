#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys


def compile_source(executable, path):
    source = path.read_text(encoding="utf-8")
    request = {
        "protocolVersion": "0.5.0",
        "rootPath": str(path.parent),
        "sourcePaths": [str(path)],
        "sourceTexts": {str(path): source},
        "mode": "project",
        "entryPath": str(path),
    }
    completed = subprocess.run(
        [executable, "--protocol"],
        input=json.dumps(request, ensure_ascii=False).encode("utf-8"),
        stdout=subprocess.PIPE,
        check=False,
    )
    return json.loads(completed.stdout.decode("utf-8"))


def main():
    executable = sys.argv[1]
    directory = pathlib.Path(__file__).parents[3] / "examples" / "manual"
    positive = [directory / f"{number:02d}_{name}.arb" for number, name in [
        (1, "basics"), (2, "composite_types"), (3, "arithmetic"),
        (4, "io"), (5, "conditions"), (6, "loops"), (7, "procedures"),
        (10, "all_rules"),
    ]]
    negative = [directory / "08_syntax_error.arb", directory / "09_semantic_error.arb"]
    for path in positive:
        response = compile_source(executable, path)
        if response.get("success") is not True:
            raise AssertionError(f"{path}: {response.get('diagnostics')}")
    for path in negative:
        response = compile_source(executable, path)
        if response.get("success") is not False:
            raise AssertionError(f"{path}: expected failure")
    print(f"manual examples passed: {len(positive)} positive, {len(negative)} negative")


if __name__ == "__main__":
    main()
