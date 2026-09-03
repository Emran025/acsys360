#!/usr/bin/env bash
set -euo pipefail

compiler=${1:?usage: verify_compiler_c_native_fixtures.sh /path/to/arabicc_c}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

python3 - "$compiler" "$repo_root" "$workdir" <<'PY'
import json
import pathlib
import subprocess
import sys

compiler, repo_root, workdir = sys.argv[1:]
examples = sorted(pathlib.Path(repo_root, "examples").glob("[0-9][0-9]_*.arb"))
if len(examples) != 10:
    raise SystemExit(f"expected 10 native fixtures, found {len(examples)}")

for index, source_path in enumerate(examples):
    source = source_path.read_text(encoding="utf-8")
    payload = {
        "protocolVersion": "0.5.0",
        "rootPath": str(source_path.parent),
        "sourcePaths": [source_path.name],
        "sourceTexts": {source_path.name: source},
        "mode": "project",
    }
    result = subprocess.run(
        [compiler, "--protocol"], input=json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        text=True, capture_output=True, check=True,
    )
    response = json.loads(result.stdout)
    if not response.get("success"):
        raise SystemExit(f"{source_path.name}: compiler rejected fixture: {response}")
    assembly = response.get("assembly", "")
    expected = response.get("executionOutput", [])
    if not assembly:
        raise SystemExit(f"{source_path.name}: empty assembly")
    stem = f"fixture_{index:02d}"
    asm_path = pathlib.Path(workdir, stem + ".asm")
    obj_path = pathlib.Path(workdir, stem + ".o")
    exe_path = pathlib.Path(workdir, stem)
    asm_path.write_text(assembly, encoding="utf-8")
    subprocess.run(["nasm", "-f", "elf64", str(asm_path), "-o", str(obj_path)], check=True,
                   capture_output=True, text=True)
    subprocess.run(["gcc", "-no-pie", str(obj_path), "-o", str(exe_path)], check=True,
                   capture_output=True, text=True)
    native = subprocess.run([str(exe_path)], check=True, capture_output=True, text=True)
    actual = [line for line in native.stdout.splitlines() if line != ""]
    expected_by_fixture = {
        "01_arithmetic.arb": ["14"],
        "02_declarations.arb": ["5", "1", "س", "لغة عربية"],
        "03_condition.arb": ["ناجح"],
        "04_while.arb": ["1", "2", "3"],
        "05_repeat_up.arb": ["1", "2", "3", "4", "5"],
        "06_repeat_down.arb": ["5", "4", "3", "2", "1"],
        "08_procedure_reference.arb": ["10"],
    }
    expected_text = expected_by_fixture.get(source_path.name, [str(value) for value in expected])
    if actual != expected_text:
        raise SystemExit(
            f"{source_path.name}: native output mismatch; expected={expected_text!r} actual={actual!r}"
        )
    print(f"native fixture {source_path.name}: PASS")
PY
