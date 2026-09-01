#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <arabicc_c-executable>" >&2
  exit 64
fi

compiler="$1"
response="$(printf '%s\n' '{"protocolVersion":"0.5.0","rootPath":"/tmp","sourcePaths":["smoke.arb"],"sourceTexts":{"smoke.arb":"برنامج اختبار { متغير س: صحيح; س = 2; اطبع(س); }."},"mode":"project"}' | "$compiler" --protocol)"

RESPONSE="$response" python3 - <<'PY'
import json
import os

response = json.loads(os.environ['RESPONSE'])
assert response['protocolVersion'] == '0.5.0'
assert response['success'] is True
assert response['diagnostics'] == []
assert response['tokens']
assert response['executionOutput'] == ['2']
assert response['symbolTable']
assert isinstance(response['syntaxTree'], dict)
assert isinstance(response['intermediateRepresentation'], dict)
print('C compiler protocol smoke: PASS')
PY
