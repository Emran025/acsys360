# arabicc C

هذا هو التنفيذ C المستقل للمترجم العربي. يبقى `compiler_core` المرجع السلوكي خلال فترة التكافؤ، ولا يتغير تطبيق Flutter أثناء بناء البديل.

## البناء

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

الهدف الأول هو تنفيذ contract protocol `0.5.0` ثم نقل مراحل Lexer وParser وSemantic وTAC وTyped IR وNASM backend وruntime على بوابات تكافؤ مستقلة. لا يُستخدم هذا executable من الواجهة قبل اكتمال تلك البوابات.
