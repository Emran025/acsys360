# Baseline الحالي للـ C compiler backend

## النطاق التنفيذي

المترجم العامل موجود في `packages/compiler_c/` ويُبنى عبر CMake وFlex وBison إلى executable باسم `arabicc`. يستهلك التطبيق هذا executable من data layer عبر JSON Protocol `0.5.0`؛ وتوجد النماذج والتحقق من العقد في `packages/compiler_contracts/`.

يمر مسار الترجمة في compiler C من protocol request إلى Lexer وParser/AST والتحليل الدلالي، ثم TAC وTyped IR. بحسب الطلب والنجاح، تتضمن الاستجابة نتائج interpreter وAssembly النصية وبيانات artifact. المكونات موضحة في [`packages/compiler_c/README.md`](../../packages/compiler_c/README.md) و[CMakeLists](../../packages/compiler_c/CMakeLists.txt)، مع خريطة وظائف مفصلة في [خريطة الشيفرة](./project-code-map.md).

## التنفيذ والاختبارات

| المجال | التنفيذ الحالي | اختبار/دليل قائم |
|---|---|---|
| executable | `src/main.c` وCMake target باسم `arabicc` | اختبارات CTest لـ`--version` و`--help` |
| Lexer وParser | `src/lexer.l` و`src/parser.y` مع AST في `src/ast.c` | اختبارات compiler integration والأمثلة اليدوية |
| Semantic | `src/semantic.c` | protocol smoke، fixtures سلبية، ونتائج `symbolTable` و`diagnostics` |
| Protocol | `src/protocol.c` و`src/protocol/` | `packages/compiler_c/tests/protocol_smoke.dart` وعقد `packages/compiler_contracts/test/` |
| TAC وTyped IR | `src/ir/tac.c` و`src/ir/typed_ir.c` | `tac_golden_test.c` وحقول الاستجابة |
| Interpreter | `src/runtime/interpreter.c` | protocol smoke واختبارات أمثلة CMake |
| Assembly | `src/backend/x86_64/` | `asm_3ac_golden_test.c` و`assembly` النصية |
| Artifact/toolchain | `src/backend/artifact_builder.c` و`src/backend/toolchain.c` | `artifact_security_test.c` و`native_3ac_smoke.sh` |
| Assist | `--assist` في executable | `assist_protocol_test.dart` يختبر نماذج العقد؛ لا يوجد في CMake الحالي اختبار integration مستقل لمسار executable `--assist` |
| Bundle | compiler يُرفق داخل ملفات Desktop في release workflow | `tool/verify_compiler_bundle.dart` لكل bundle منشور |

يسجل CMake اختبارات integration إضافية عند العثور على Dart، ومنها protocol smoke والأمثلة اليدوية واختبارات الفاصلة المنقوطة والأنواع المركبة والاستقرار. أما CI الرئيسي فيبني compiler ويشغل CTest؛ راجع `.github/workflows/ci.yml` لنطاق كل job.

## حدود الاستنتاج

لا تعني الاختبارات الموجودة اكتمال كل productions أو دعم artifact على كل منصة. تحقق من اختبار بعينه قبل إعلان دعم construct أو target. حقل `assembly` يحتوي نص Assembly ولا يثبت وحده إنشاء ملف تنفيذي. اسم target `dart-native` قيمة بروتوكول يخدمها backend C، وليس implementation بلغة Dart.

لا توجد في البنية الحالية حزمة `packages/compiler_core` أو CLI Dart مستقل باسم `apps/compiler_cli`. أي ظهور لهذين المسارين في سجل migration أو audit قديم تاريخي، وليس دليلًا على مسار تشغيل حالي.

## المراجع

- [معمارية المشروع](./architecture.md)
- [مصفوفة القبول وحدود compiler](./compiler-c-acceptance-matrix.md)
- [عقد protocol](./compiler-protocol.md)
- [استراتيجية الاختبار](../testing/test-strategy.md)
