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
برنامج إدخال؛ متغير س: صحيح؛ متغير معدل: حقيقي؛ متغير موافق: منطقي؛ متغير اسم: خيط_رمزي؛ متغير الحرف: حرفي؛
{ اقرأ(س)؛ اقرأ(معدل)؛ اقرأ(موافق)؛ اقرأ(اسم)؛ اقرأ(الحرف)؛ اطبع(س، معدل، موافق، اسم، الحرف)؛ }.
SRC
"$compiler" --asm <"$tmp/input.arb" >"$tmp/input.asm"
nasm -f elf64 "$tmp/input.asm" -o "$tmp/input.o"
cc -no-pie "$tmp/input.o" -o "$tmp/input"
printf '7\n2.5\nصح\nعلي\nأ\n' | "$tmp/input" >"$tmp/input.output"
test "$(grep -c '"requestType":"input"' "$tmp/input.output")" -eq 5
test "$(tail -5 "$tmp/input.output")" = '7
2.5
صح
علي
أ'
cat >"$tmp/sort_array.arb" <<'SRC'
برنامج ترتيب_مصفوفة؛ ثابت الحجم = 5؛ نوع مصفوفة_اعداد = قائمة[الحجم] من صحيح؛
متغير الأصلية: مصفوفة_اعداد؛ متغير نسخة_العمل: مصفوفة_اعداد؛ متغير ث, ت, قيمة_مؤقتة: صحيح؛
إجراء اقرأ_المصفوفة()؛ {
  كرر(ث = 0 الى 4 أضف 1) { اقرأ(قيمة_مؤقتة)؛ الأصلية[ث] = قيمة_مؤقتة؛ }؛
}؛
إجراء انسخ_المصفوفة()؛ { كرر(ث = 0 الى 4 أضف 1) نسخة_العمل[ث] = الأصلية[ث]؛ }؛
إجراء اطبع_المصفوفة()؛ { كرر(ث = 0 الى 4 أضف 1) اطبع(نسخة_العمل[ث])؛ }؛
إجراء رتب_المصفوفة()؛ {
  كرر(ث = 0 الى 3 أضف 1) {
    كرر(ت = 0 الى 3 أضف 1) {
      إذا(نسخة_العمل[ت] > نسخة_العمل[ت + 1]) فان {
        قيمة_مؤقتة = نسخة_العمل[ت]؛ نسخة_العمل[ت] = نسخة_العمل[ت + 1]؛
        نسخة_العمل[ت + 1] = قيمة_مؤقتة؛
      }؛
    }؛
  }؛
}؛
{ اقرأ_المصفوفة()؛ انسخ_المصفوفة()؛ اطبع_المصفوفة()؛ رتب_المصفوفة()؛ اطبع_المصفوفة()؛ }.
SRC
"$compiler" --asm <"$tmp/sort_array.arb" >"$tmp/sort_array.asm"
nasm -f elf64 "$tmp/sort_array.asm" -o "$tmp/sort_array.o"
cc -no-pie "$tmp/sort_array.o" -o "$tmp/sort_array"
printf '9\n2\n7\n1\n5\n' | "$tmp/sort_array" >"$tmp/sort_array.output"
test "$(grep -c '"requestType":"input"' "$tmp/sort_array.output")" -eq 5
test "$(grep -v '"requestType":"input"' "$tmp/sort_array.output" | tail -10)" = '9
2
7
1
5
1
2
5
7
9'
cat >"$tmp/default_parameters.arb" <<'SRC'
برنامج اختبار_القيم_الافتراضية؛
إجراء اجمع(بالقيمة أ: صحيح؛ بالقيمة ب: صحيح = 1 + 2؛ بالقيمة ج: صحيح = 4)؛
{
  اطبع(أ + ب + ج)؛
}؛
إجراء اجمع_مجموعة(بالقيمة س: صحيح؛ بالقيمة ص، ع: صحيح = 4)؛
{
  اطبع(س + ص + ع)؛
}؛
{
  اجمع(1)؛
  اجمع(1، 2)؛
  اجمع_مجموعة(1)؛
}.
SRC
"$compiler" --asm <"$tmp/default_parameters.arb" >"$tmp/default_parameters.asm"
nasm -f elf64 "$tmp/default_parameters.asm" -o "$tmp/default_parameters.o"
cc -no-pie "$tmp/default_parameters.o" -o "$tmp/default_parameters"
test "$("$tmp/default_parameters")" = '8
7
9'
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
