#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile

EXE = sys.argv[1]

def request(source, **extra):
    value = {
        'protocolVersion': '0.5.0',
        'rootPath': '.',
        'sourcePaths': ['main.arb'],
        'sourceTexts': {'main.arb': source},
        'mode': 'project',
        'entryPath': 'main.arb',
        'execute': True,
    }
    value.update(extra)
    return value

def run(req, interactive=False, values=None):
    p = subprocess.Popen([EXE, '--protocol'], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, bufsize=1)
    p.stdin.write(json.dumps(req, ensure_ascii=False) + '\n')
    p.stdin.flush()
    if not interactive:
        p.stdin.close()
        out = p.stdout.read()
        err = p.stderr.read()
        p.wait()
        return p.returncode, json.loads(out), err
    lines = []
    while True:
        line = p.stdout.readline()
        if not line:
            break
        value = json.loads(line)
        if value.get('requestType') == 'input':
            p.stdin.write(json.dumps({'value': values.pop(0)}, ensure_ascii=False) + '\n')
            p.stdin.flush()
        else:
            lines.append(value)
            break
    p.stdin.close()
    rest = p.stdout.read()
    if rest.strip():
        lines.append(json.loads(rest.strip().splitlines()[-1]))
    err = p.stderr.read()
    return p.wait(), lines[-1], err

def check(condition, message):
    if not condition:
        raise AssertionError(message)

valid = run(request('برنامج اختبار؛ متغير س: صحيح؛ { س = 42؛ اطبع(س)؛ }.'))
check(valid[0] == 0 and valid[1]['success'] is True, 'valid compile')
check(valid[1]['executionOutput'] == ['42'], 'execute output')

bad_json = subprocess.run([EXE, '--protocol'], input='{not-json}\n', text=True,
                          capture_output=True, check=False)
check(bad_json.stdout.strip(), 'invalid json response missing')
bad_json_response = json.loads(bad_json.stdout)
check(bad_json_response['success'] is False, 'invalid json should fail')

syntax = run(request('برنامج اختبار؛ متغير س: صحيح؛ { س = ؛ }.'))
check(syntax[0] != 0 and syntax[1]['success'] is False, 'syntax failure')
check(any(d['phase'] == 'syntax' for d in syntax[1]['diagnostics']), 'syntax diagnostic')

semantic = run(request('برنامج أنواع؛ متغير رقم: صحيح؛ متغير نص: خيط_رمزي؛ { رقم = نص؛ }.'))
check(semantic[0] != 0 and semantic[1]['success'] is False, 'semantic failure')
check(any(d['phase'] == 'semantic' for d in semantic[1]['diagnostics']), 'semantic diagnostic')

project = run(request('برنامج مشروع؛ { اطبع(7)؛ }.'))
check(project[0] == 0 and project[1]['success'] is True, 'project IO')

execute_false = run(request('برنامج تحليل؛ { اطبع(7)؛ }.', execute=False))
check(execute_false[0] == 0 and execute_false[1]['executionOutput'] == [], 'execute false')

interactive = run(request('برنامج قراءة؛ متغير س: صحيح؛ متغير ص: صحيح؛ { اقرأ(س)؛ اقرأ(ص)؛ اطبع(س)؛ اطبع(ص)؛ }.', mode='active', inputValues={}, interactive=True), interactive=True, values=['11', '22'])
check(interactive[0] == 0 and interactive[1]['executionOutput'] == ['11', '22'], 'interactive input')

with tempfile.TemporaryDirectory(prefix='acsys360-artifact-') as artifact:
    artifact_result = run(request('برنامج أصلي؛ متغير سعر: حقيقي؛ { سعر = 2.5؛ }.', target='dart-native', artifactDirectory=artifact))
    check(artifact_result[0] == 0 and artifact_result[1]['success'] is True, 'artifact compile')
    artifacts = artifact_result[1]['artifacts']
    check(artifacts and all(os.path.exists(path) for path in artifacts), 'artifact files')

print('protocol matrix: PASS')
