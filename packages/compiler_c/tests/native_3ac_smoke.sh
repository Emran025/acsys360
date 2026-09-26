#!/bin/sh
set -eu
compiler=$1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/program.arb" <<'SRC'
برنامج اختبار؛ متغير أ: حقيقي؛ متغير ب: حقيقي؛ متغير ن: منطقي؛ { أ = 2.5؛ ب = 3.5؛ ن = أ < ب؛ إذا(ن && صح) فان اطبع("نعم")؛ وإلا اطبع("لا")؛ }.
SRC
"$compiler" --asm <"$tmp/program.arb" >"$tmp/program.asm"
nasm -f elf64 "$tmp/program.asm" -o "$tmp/program.o"
cc -no-pie "$tmp/program.o" -o "$tmp/program"
test "$("$tmp/program")" = 'نعم'
cat >"$tmp/input.arb" <<'SRC'
برنامج إدخال؛ متغير س: صحيح؛ متغير معدل: حقيقي؛ متغير موافق: منطقي؛ متغير اسم: خيط_رمزي؛ { اقرأ(س)؛ اقرأ(معدل)؛ اقرأ(موافق)؛ اقرأ(اسم)؛ اطبع(س، معدل، موافق، اسم)؛ }.
SRC
"$compiler" --asm <"$tmp/input.arb" >"$tmp/input.asm"
nasm -f elf64 "$tmp/input.asm" -o "$tmp/input.o"
cc -no-pie "$tmp/input.o" -o "$tmp/input"
printf '7\n2.5\n1\nعلي\n' | "$tmp/input" >"$tmp/input.output"
test "$(grep -c '"requestType":"input"' "$tmp/input.output")" -eq 4
test "$(tail -4 "$tmp/input.output")" = '7
2.5
صح
علي'
cat >"$tmp/regressions.arb" <<'SRC'
برنامج تراجعات؛ ثابت حد = 2 + 3؛ متغير صحيح_م: صحيح؛ متغير حقيقي_م: حقيقي؛ متغير سالب: حقيقي؛ متغير i: صحيح؛ { صحيح_م = 4؛ حقيقي_م = صحيح_م + 2.5؛ سالب = -2.5؛ اطبع(حد، حقيقي_م، سالب)؛ كرر(i = 3 الى 1 أضف -1) اطبع(i)؛ }.
SRC
"$compiler" --asm <"$tmp/regressions.arb" >"$tmp/regressions.asm"
nasm -f elf64 "$tmp/regressions.asm" -o "$tmp/regressions.o"
cc -no-pie "$tmp/regressions.o" -o "$tmp/regressions"
test "$("$tmp/regressions")" = '5
6.5
-2.5
3
2
1'
python3 - "$compiler" <<'PY'
import json, subprocess, sys
source='برنامج حلقات؛ متغير س: صحيح؛ { كرر(س = 1 الى 3 أضف 1) اطبع(س)؛ }.'
request={'protocolVersion':'0.5.0','rootPath':'/tmp','sourcePaths':['loop.arb'],'sourceTexts':{'loop.arb':source},'mode':'file','target':'interpreter'}
out=subprocess.check_output([sys.argv[1],'--protocol'], input=(json.dumps(request,ensure_ascii=False)+'\n').encode())
items=json.loads(out)['threeAddressCode']
assert any(x.startswith('LABEL ') for x in items)
assert any(x.startswith('BRANCH ') for x in items)
assert any(' <= ' in x for x in items)
PY
