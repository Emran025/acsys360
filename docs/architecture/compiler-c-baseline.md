# Baseline للـ C compiler backend

## النطاق الحالي

المرجع التنفيذي الحالي هو `packages/compiler_c`. يبني هذا المجلد executable `arabicc` باستخدام Flex وBison وCMake. ويتصل التطبيق به عبر JSON Protocol الإصدار `0.5.0` من خلال `packages/compiler_contracts`.

يوفر backend الحالي Lexer وParser وAST وتحليلًا دلاليًا محدودًا وتوليد Assembly نصية ضمن subset موثق. توجد اختبارات CMake للفحص التشغيلي (`--version` و`--help`)، ويغطي smoke test في `tool/verify_compiler_bundle.dart` المسار الكامل من طلب JSON إلى استجابة JSON بعد تضمين executable.

## المكونات الحالية

| المجال | التنفيذ الحالي | دليل التحقق |
|---|---|---|
| Lexer | `src/lexer.l` عبر Flex، مع رموز عربية ومواقع مصدر | smoke test ونتيجة `tokens` |
| Parser | `src/parser.y` عبر Bison وبناء AST | نتيجة `syntaxTree` |
| Semantic | `src/semantic.c` ورموز وتشخيصات محدودة | `symbolTable` و`diagnostics` |
| Protocol | `src/protocol.c` و`include/protocol.h` | `protocolVersion: 0.5.0` وJSON round-trip |
| Assembly | `src/asm_x86_64.c`، نص NASM-like محدود | حقل `assembly` |
| Assist | `--assist` في executable | طلبات المساعدة من المحرر |
| Packaging | CMake ثم bundling في `release.yml` | Linux وWindows وmacOS smoke tests |

## قواعد القياس

لا تُحسب مرحلة مكتملة إلا إذا امتلكت تنفيذًا في C واختبارًا مستقلًا، وظهرت نتيجتها في عقد JSON أو artifact موثق، ونجحت على runner المنصة المعنية. لا يُسمح بتفعيل نتيجة ثابتة داخل Flutter بدل استجابة `arabicc`، ولا يُسمح بوصف Assembly النصية بأنها binary.

## حدود المقارنة التاريخية

كانت وثائق سابقة تشير إلى `packages/compiler_core` و`apps/compiler_cli` ونسخة Dart من المترجم. هذه المسارات لم تعد البنية المنفذة في المستودع الحالي. يجب قراءة تلك الإشارات بوصفها تصميمًا تاريخيًا أو خطة انتقال، بينما تكون المسارات المعتمدة للتنفيذ هي `packages/compiler_c` و`packages/compiler_contracts` و`lib/features/editor/data`.

## References

[1]: https://github.com/Emran025/acsys360/tree/main/packages/compiler_c "Current C compiler backend"
[2]: https://github.com/Emran025/acsys360/tree/main/packages/compiler_contracts "Current compiler contracts"
[3]: https://github.com/Emran025/acsys360/blob/main/tool/verify_compiler_bundle.dart "Bundled compiler smoke test"

المراجع: [1] [2] [3]
