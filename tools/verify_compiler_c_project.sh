#!/usr/bin/env bash
set -euo pipefail

compiler=${1:?compiler executable is required}
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

printf '%s\n' '{"protocolVersion":"0.5.0","rootPath":"/tmp","sourcePaths":["main.arb","lib.arb"],"sourceTexts":{"lib.arb":"برنامج مكتبة { متغير ل: صحيح؛ ل = 99؛ }.","main.arb":"برنامج رئيسي { متغير س: صحيح؛ س = 2؛ اطبع(س)؛ }."},"mode":"project"}' |
  "$compiler" --protocol > "$tmp_dir/valid.json"
printf '%s\n' '{"protocolVersion":"0.5.0","rootPath":"/tmp","sourcePaths":["main.arb","bad.arb"],"sourceTexts":{"main.arb":"برنامج رئيسي { متغير س: صحيح؛ س = 2؛ اطبع(س)؛ }.","bad.arb":"برنامج مكسور { متغير ص: ؛ }."},"mode":"project"}' |
  "$compiler" --protocol > "$tmp_dir/invalid.json" || test "$?" -eq 1

python3 - "$tmp_dir" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
valid = json.loads((root / 'valid.json').read_text(encoding='utf-8'))
invalid = json.loads((root / 'invalid.json').read_text(encoding='utf-8'))
assert valid['success'] is True, valid['diagnostics']
assert valid['syntaxTree']['sourcePath'] == 'main.arb'
assert valid['executionOutput'] == ['2'], valid['executionOutput']
assert invalid['success'] is False
print('C compiler project protocol: PASS')
PY
