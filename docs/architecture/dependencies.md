# الاعتماديات والأدوات

## سياسة الاختيار

تُضاف dependency فقط عندما يكون لها دور واضح يمكن اختباره وشرحه. يعتمد المشروع على Flutter للواجهة، وعلى Dart لعقود التكامل وأدوات المحرر، وعلى CMake وFlex وBison لبناء backend المترجم. لا تحتوي الواجهة على parser موازٍ لقواعد اللغة.

| الأداة أو المكتبة | الإصدار أو المصدر | الغرض | موضع الاستخدام | الحد المعتمد |
|---|---|---|---|---|
| Flutter | `3.44.5` في CI وRelease | بناء واجهة Desktop والاختبارات المرئية | `lib/`, `test/`, ومنصات Desktop | لا ينفذ grammar أو semantic analysis |
| Dart | SDK المرفق مع Flutter | لغة التطبيق وعقد JSON وأدوات التحقق | ملفات `.dart` و`tool/` و`packages/compiler_contracts` | لا يستبدل executable المترجم C |
| `file_picker` | مثبت في `pubspec.lock` | اختيار ملف أو مجلد workspace | شاشة المحرر وعمليات workspace | لا يدير الحالة ولا يقرأ اللغة |
| `compiler_contracts` | path package في `packages/compiler_contracts` | نماذج وتحليل JSON Protocol `0.5.0` | التطبيق والاختبارات | لا يحتوي implementation للمترجم |
| Flex | أداة نظام | توليد scanner من `packages/compiler_c/src/lexer.l` | CMake وCI | على Windows يعمل بوضع `--wincompat` |
| Bison | أداة نظام | توليد parser من `packages/compiler_c/src/parser.y` | CMake وCI | تحذيرات conflicts لا تعني اكتمال grammar |
| CMake | أداة بناء | توليد ملفات البناء لكل منصة | `packages/compiler_c/CMakeLists.txt` | لا يحدد قواعد اللغة |
| C compiler | MSVC أو GCC/Clang | بناء executable `arabicc` | `packages/compiler_c` | backend الحالي مستقل عن Flutter |
| Cairo font | `assets/fonts/Cairo.ttf` | عرض واجهة عربية ثابتة | `pubspec.yaml` وtheme | لا يؤثر على compiler |

## البنية البرمجية الفعلية

يتكون تطبيق Flutter من feature واحدة رئيسية حاليًا هي `lib/features/editor`. تحتوي `domain` على الكيانات والعقود وعمليات الاستخدام، وتحتوي `data` على تنفيذ filesystem وتشغيل عملية `arabicc`، بينما تحتوي `presentation` على controller والواجهة وWidgets. توجد الخدمات والثوابت العامة في `lib/core` والمكونات والثيمات المشتركة في `lib/shared`.

أما المترجم المستقل فيوجد في `packages/compiler_c`. ويضم `src/lexer.l` و`src/parser.y` وملفات AST والتحليل الدلالي والبروتوكول وbackend Assembly، إضافة إلى headers في `include`. لا يوجد حاليًا مجلد `packages/compiler_core` أو تطبيق `apps/compiler_cli`؛ هذه أسماء كانت في التصميم السابق وليست مسارات يجب استخدامها.

## أدوات التحقق والبناء

| الأداة | الغرض | الاستخدام |
|---|---|---|
| `dart format` | تنسيق Dart | قبل الدمج وعلى ملفات التطبيق والحزم |
| `flutter analyze` | تحليل ساكن | بوابة CI الأساسية |
| `flutter test` | اختبارات Flutter والعقد | CI وRelease |
| `cmake --build` | بناء `arabicc` | كل منصة مستهدفة |
| `ctest` | اختبارات C البسيطة | `--version` و`--help` |
| `tool/verify_compiler_bundle.dart` | Smoke test للتكامل | بعد تضمين executable داخل Desktop bundle |
| GitHub Actions | CI وRelease وصورة GHCR | `ci.yml` و`release.yml` و`container.yml` |

## قواعد مهمة

يجب تشغيل `arabicc` من خلال repository أو data source في التطبيق، وليس من Widget مباشرة. يجب أن تمر نتائج المترجم عبر `compiler_contracts` قبل تحويلها إلى كيانات domain. لا يجوز اعتبار النص الناتج من `asm_x86_64.c` executable binary دون assembler فعلي. كما لا يجوز اعتبار وجود `file_picker` دليلًا على اكتمال workspace؛ اكتمال workspace ناتج عن repository والكيانات والاختبارات معًا.

## References

[1]: https://github.com/Emran025/acsys360/blob/main/pubspec.yaml "Application dependencies"
[2]: https://github.com/Emran025/acsys360/tree/main/packages/compiler_c "Standalone C compiler backend"
[3]: https://github.com/Emran025/acsys360/tree/main/packages/compiler_contracts "Compiler protocol contracts"
[4]: https://github.com/Emran025/acsys360/blob/main/.github/workflows/ci.yml "Continuous integration workflow"

المراجع: [1] [2] [3] [4]
