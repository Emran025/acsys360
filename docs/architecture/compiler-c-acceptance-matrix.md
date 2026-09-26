# حالة تنفيذ compiler C وحدود التغطية

## النطاق

هذه المصفوفة تصف التنفيذ الحالي، لا خطة استبدال مستقبلية. يستخدم تطبيق Flutter executable `arabicc` المبني من `packages/compiler_c/` عبر JSON Protocol `0.5.0`. تحفظ نماذج الطلب والاستجابة المشتركة في `packages/compiler_contracts/`. تفاصيل الطبقات ومسار الطلب موجودة في [وثيقة المعمارية](./architecture.md) و[خريطة الشيفرة](./project-code-map.md)، وبوابات CI في `.github/workflows/ci.yml`.

## التنفيذ وأدلة التحقق

| المجال | التنفيذ الحالي | دليل التحقق في المستودع | الحدود |
|---|---|---|---|
| بناء C | C17، Flex، Bison وCMake لبناء `arabicc` | `packages/compiler_c/CMakeLists.txt` وjob `compiler-c` في CI | يلزم توفر أدوات البناء |
| Lexer وParser/AST | `src/lexer.l` و`src/parser.y` و`src/ast.c` | اختبارات الأمثلة والبروتوكول في `packages/compiler_c/tests/` | تغطية اللغة تتبع grammar المنفذة، وليست ادعاءً باكتمال اللغة |
| Semantic وDiagnostics | `src/semantic.c` وبيانات الاستجابة | `protocol_smoke.dart` واختبارات compiler | القدرات محدودة بما يطبقه backend |
| TAC وTyped IR | `src/ir/tac.c` و`src/ir/typed_ir.c` | `tac_golden_test.c` ونتائج البروتوكول | Typed IR وسيط، وليس machine code |
| Runtime | `src/runtime/interpreter.c` | اختبارات protocol والأمثلة المسجلة في CMake | التشغيل ضمن التركيبات التي يدعمها compiler |
| Assembly وartifact | `src/backend/x86_64/` و`src/backend/artifact_builder.c` و`src/backend/toolchain.c` | `asm_3ac_golden_test.c` و`native_3ac_smoke.sh` و`artifact_security_test.c` | `assembly` نص؛ artifact منفصل ومحدود بالـtarget والـtoolchain |
| Protocol | `src/protocol/` و`packages/compiler_contracts/` | اختبارات العقد و`packages/compiler_c/tests/protocol_smoke.dart` | يجب تحديث الجانبين معًا عند تغيير schema |
| Assist | executable يقبل `--assist`، وحزمة Dart تعرف موديلات assist | `packages/compiler_contracts/test/assist_protocol_test.dart` يختبر نماذج العقد؛ لا يوجد حاليًا اختبار CTest مستقل لتكامل executable assist | لا يعني اكتمال ميزات Language Server |
| Flutter integration | `ProcessCompilerRepository` يشغّل executable | `test/process_compiler_repository_test.dart` واختبارات التطبيق | لا تستدعي Widgets compiler أو أدوات toolchain مباشرة |
| CI | jobs للعقد وC وFlutter وبناء Linux Desktop | `.github/workflows/ci.yml` | راجع workflow نفسه لنطاق المنصات المنشور |

## قاعدة وصف الدعم

وجود ملف تنفيذ أو حقل في JSON لا يثبت دعم كل قواعد اللغة. عند توثيق دعم construct أو artifact، اربط الادعاء باختبار في المترجم أو fixture يستخدمه اختبار التكامل. لا توصف قيمة target `dart-native` بأنها مترجم Dart؛ هي اسم target ينفذه backend C. كما لا توصف نصوص Assembly بأنها ملفات تنفيذية.
