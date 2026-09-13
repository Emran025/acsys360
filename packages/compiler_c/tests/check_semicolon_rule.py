#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

binary = Path(__file__).resolve().parent.parent / 'build' / 'arabicc'
source_path = '/workspace/main.arb'

def compile_source(source):
    request = {
        'protocolVersion': '0.5.0',
        'rootPath': '/workspace',
        'sourcePaths': [source_path],
        'sourceTexts': {source_path: source},
        'mode': 'active',
        'entryPath': source_path,
        'target': 'none',
    }
    result = subprocess.run(
        [str(binary), '--protocol'],
        input=json.dumps(request, ensure_ascii=False) + '\n',
        text=True,
        capture_output=True,
    )
    if not result.stdout.strip():
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)

valid = compile_source('برنامج اختبار؛ { اطبع(1)؛ }.')
invalid = compile_source('برنامج اختبار؛ { اطبع(1) }.')
assert valid['success'] is True, valid
assert invalid['success'] is False, invalid
assert invalid['diagnostics'], invalid
print(json.dumps({'valid': valid['success'], 'missing_semicolon': invalid['success'], 'diagnostic': invalid['diagnostics'][0]}, ensure_ascii=False))
