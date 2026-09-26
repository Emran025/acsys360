# دليل مكونات الشيفرة

هذا الدليل يشرح توزيع المسؤوليات ومسار الاستدعاء الأساسي في النسخة الحالية. وهو ليس بديلًا عن [خريطة الشيفرة التفصيلية](../architecture/project-code-map.md)، التي تعرض شجرة الملفات، ومسؤولية الوحدات، والاعتماديات، وأدوات التطوير والاختبار.

## الصورة العامة

يتكون النظام من تطبيق Flutter/Dart ومترجم C مستقل. التطبيق لا يربط compiler عبر FFI؛ بل يشغّل الملف التنفيذي `arabicc` كعملية نظام، ويرسل طلبات JSON عبر stdin، ثم يحلل الاستجابة القادمة من stdout. العقد `compiler_contracts` يوحد شكل الرسائل والتحقق منها بين Dart وC.

```text
واجهة Flutter
  → EditorController وحالات المحرر
  → use cases / repositories
  → ProcessCompilerRepository
  → عملية arabicc وJSON Protocol 0.5.0
  → compiler_driver_run
  → Frontend → Semantic/IR → Interpreter أو Backend
  → استجابة منظمة إلى المحرر ولوحات النتائج
```

## المكونات ومسؤولياتها

| الجزء | المسؤولية وحدودها |
|---|---|
| `lib/main.dart`, `lib/config/di/injection.dart`, `lib/routes/app_router.dart` | نقطة التشغيل وتركيب الاعتماديات والتوجيه إلى `EditorShell`. لا تحتوي منطق الترجمة. |
| `lib/features/editor/presentation/` | عرض `EditorShell`، وإدارة أحداث الواجهة وعرض الوثائق والتبويبات والشجرة والنتائج. لا ينبغي أن تنفذ عمليات نظام أو ترجمة داخل widgets. |
| `EditorController` | في `presentation/controllers/`؛ ينسق الحالة ويستدعي domain use cases وrepositories مباشرة. لا توجد طبقة application مستقلة في tree الحالية. |
| `lib/features/editor/domain/usecases/` | حالات استخدام مستقلة مثل `OpenDocument` و`SaveDocument` و`ApplyEdit` و`UndoEdit` و`RedoEdit` وخدمة اللغة والبحث والتنسيق والتعليق؛ تعمل على عقود ومستندات domain. لا توجد مجلدات `application/` أو controller منفصل عن presentation في البنية الحالية. |
| `lib/features/editor/domain/` | نماذج وقواعد المحرر وسياساته، مثل المستندات ومسارات الملفات وسياسة الوصول. يجب أن تبقى مستقلة عن Flutter وعن تفاصيل JSON. |
| `lib/features/editor/data/` | تنفيذ منافذ الملفات وcompiler وتشغيل البرامج. هنا تقع حدود التعامل مع filesystem والعملية `arabicc`. |
| `ProcessCompilerRepository` | تحويل طلبات التطبيق إلى رسائل البروتوكول، تشغيل compiler وقراءة مخرجاته، ثم تحويل الاستجابة إلى نماذج التطبيق. لا يترجم الشيفرة بنفسه. |
| `packages/compiler_contracts/` | نماذج ورسائل JSON ذات الإصدار 0.5.0 والتحقق من شكلها في Dart؛ لا تنفذ lexer أو parser ولا تستبدل تعامل executable C مع الطلب. |
| `packages/compiler_c/src/protocol/` و`src/driver/compiler_driver.c` | تحليل/تسلسل protocol وتنسيق مراحل compiler، بما فيها handler المساعدة `protocol_handle_assist`. |
| Frontend في compiler C | Lexer يجزّئ المصدر، وParser يبني AST؛ يرفق التشخيصات والبنى التي تحتاجها المراحل اللاحقة. |
| Semantic وIR في compiler C | فحص المعاني والأنواع، وبناء التمثيل الوسيط والتحويلات ذات الصلة قبل التنفيذ أو توليد المخرجات. |
| Runtime في compiler C | تنفيذ AST/التمثيل المدعوم، عبر دورة `runtime_begin` و`runtime_execute_ast` و`runtime_end`. |
| Backend وtoolchain في compiler C | توليد المخرجات المدعومة وإدارة بناء وتشغيل artifact عند طلبها. `artifact_build_native` يبني artifact، و`toolchain_run_process` يشغّل أداة نظام؛ وهما ليسا جزءًا من واجهة Flutter. |
| `packages/compiler_c/src/main.c` | نقطة دخول CLI: وضع البروتوكول والمساعدة يعالجان رسائل الأسطر، و`--asm` يقرأ الإدخال حتى EOF. |

## مسارات العمل

### تشغيل التطبيق وفتح المحرر

1. يبدأ `main()` من `lib/main.dart` تهيئة Flutter والخدمات.
2. يهيئ `ServiceLocator` implementations للخدمات والمستودعات، ثم يوجه `AppRouter` إلى واجهة المحرر.
3. يربط `EditorShell` عناصر الواجهة بـ`EditorController`؛ وتعرض widgets الحالة ولا تنشئ ملكية ثانية للبيانات.
4. يطلب المحرر workspace أو مستندًا، ثم تمر عملية الملفات عبر use case/repository حتى منفذ النظام.

### فتح الملفات وحفظها وإدارة workspace

واجهة Explorer ترسل أحداث الاختيار والإنشاء وإعادة التسمية والحذف إلى طبقة التطبيق. تتحقق سياسات المسارات من العمليات المسموح بها، وتقوم repositories بعمليات filesystem. بعد نجاح العملية، تُحدّث حالة المستندات والشجرة؛ أما فشل النظام فيبقى خطأً ظاهرًا ولا يتحول إلى نجاح صوري.

### Compile وAssist

1. يطلب المحرر compile أو assist للنص الحالي؛ ينسق `EditorController` الطلب وحالة الانتظار والنتيجة.
2. يستدعي use case مستودع compiler. يحول `ProcessCompilerRepository` الطلب إلى JSON وفق العقد ويشغل `arabicc`.
3. يدخل الطلب من `main.c` إلى مسار البروتوكول، ثم إلى `c_run_protocol` ومشغل compiler `compiler_driver_run`.
4. يعالج compiler C النص بالمراحل المطلوبة للطلب، ويعيد التشخيصات والنتائج ضمن استجابة JSON.
5. يتحقق Dart من شكل الرسالة ويحول بياناتها إلى نماذج، ثم يعرض الواجهة التشخيصات والمخرجات في اللوحات المناسبة.

الـsyntax highlighting الفوري في المحرر تجربة عرض مستقلة عن طلب compiler الكامل؛ لا ينبغي تفسيرها على أنها تشغيل للمترجم لكل تغيير نصي. تُراجع تفاصيل تحديث النص وتحليل الإدخال المؤجل في [سلوك المحرر](04-editor-behavior.md).

### Build وتشغيل البرنامج

الترجمة والتحليل لا تساويان بناء برنامج أصلي. عندما يطلب المستخدم بناء artifact أو تشغيله، يمر الطلب إلى backend C وأدوات toolchain المناسبة. `dart-native` اسم target يرسله العميل ويعالجه backend C، وليس مترجم Dart بديلًا. كما أن Assembly الناتج نص مصدر، وليس بحد ذاته executable. ينسق `EditorController` البناء والتشغيل، وتعرض الواجهة الحالة والنتائج.

## الحدود والمسؤولية

- لا تستورد واجهة العرض تفاصيل بروتوكول C أو تنفذ عمليات filesystem مباشرة.
- لا يفسر `compiler_contracts` الشيفرة؛ وظيفته نمذجة والتحقق من رسائل العقد.
- لا يضمن نجاح بناء artifact لمجرد نجاح parsing أو semantic analysis.
- عمليات التفاعل مع الملفات وأدوات النظام تنتمي إلى data/toolchain boundaries، وتعيد أخطاء صريحة إلى طبقة العرض.
- أرقام البروتوكول وادعاءات الميزات تخضع للعقد والتنفيذ الحاليين؛ الخطط لا تثبت أن الميزة منفذة.

## الاختبارات والأدوات

تغطي اختبارات Dart العقود والوحدات وrepositories وwidgets؛ وتغطي اختبارات C مراحل compiler والبروتوكول وCTest؛ وتغطي أمثلة التكامل سلوك `arabicc` من خلال رسائل البروتوكول. أسماء CTest الثابتة هي `arabicc_version`, `arabicc_help`, `arabicc_tac_golden`, `arabicc_asm_3ac_golden`, `arabicc_native_3ac_smoke`, و`arabicc_artifact_security`؛ ومع Dart يسجل CMake اختبارات `arabicc_protocol_smoke`, `arabicc_manual_examples`, `arabicc_semicolon_rule`, `arabicc_composite_types`, و`arabicc_stability`. يستخدم البناء Flutter/Dart، CMake مع Flex وBison ومترجم C، وNASM/المجمّع عند الحاجة إلى target أصلي. راجع [الاعتماديات والأدوات](../architecture/dependencies.md) و[استراتيجية الاختبار](../testing/test-strategy.md) للتفاصيل.
