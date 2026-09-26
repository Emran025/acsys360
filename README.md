# acsys360 — محرر ومترجم اللغة العربية

هذا المستودع يحتوي على محرر لغة عربية مبني بـ Flutter ومترجم مستقل بلغة C. يفصل التطبيق بين الواجهة ومنطق المحرر والوصول إلى الملفات وتشغيل المترجم، بينما يتواصل مع executable المترجم عبر JSON Protocol.

## نقطة الحقيقة المعرفية

قواعد اللغة ومتطلبات التكليف محفوظة داخل:

```text
.project/skills/arabic-compiler-project/
├── SKILL.md
└── references/
    ├── language-rules.txt
    └── assignment-requirements.txt
```

يجب قراءة الـ Skill قبل تعديل أي قاعدة أو مرحلة ترجمة. لا تُستبدل اللغة العربية بصياغة C-like ولا تُقبل نتائج ثابتة بدل نتائج ناتجة عن المصدر.

## الوثائق التنفيذية

| الوثيقة | الغرض |
|---|---|
| `docs/architecture/architecture.md` | الطبقات وعقد التكامل |
| `docs/architecture/project-code-map.md` | شجرة مفصلة، تدفق البيانات، وظائف المكونات والأدوات والمكتبات |
| `docs/architecture/product-boundary.md` | حدود المنتج والحالة الحالية وسلوك Workspace Explorer |
| `docs/architecture/compiler-c-acceptance-matrix.md` | تنفيذ compiler C وأدلة اختباره وحدوده |
| `docs/assignment/04-editor-behavior.md` | سلوك الإدخال وRTL ومستكشف Workspace |
| `docs/architecture/editor-shortcuts.md` | مصفوفة أوامر المحرر واختبارها |
| `docs/assignment/12-code-component-guide.md` | سبب وجود كل مكون ومسار بياناته وحدوده |
| `docs/roadmap/roadmap.md` | حالة المراحل وأولويات العمل التالية |
| `docs/testing/test-strategy.md` | اختبارات كل مرحلة ومعايير الجودة |
| `.github/workflows/ci.yml` | بوابة CI وبناء Desktop |
| `CHANGELOG.md` | سجل الإصدارات وملاحظات البناء |

## المنتج المستهدف

يقدم المحرر مستكشف ملفات واختيار مجلد، تبويبات ووثائق، تحرير RTL، حفظ وإنشاء وفتح الملفات، قوائم explorer لإجراءات الملفات، بحثًا واستبدالًا، تنسيقًا، themes، undo/redo، تشخيصات، compile/build/run، completion/help، وMinimap ولوحات لمراحل compiler. لا تتضمن الواجهة الحالية command palette عامة أو language server كاملًا؛ راجع [حدود المنتج](docs/architecture/product-boundary.md) و[الاختصارات](docs/architecture/editor-shortcuts.md).

## أسلوب العمل

يُبنى كل تغيير في فرع مستقل ويُدمج عبر Pull Request بعد نجاح format وanalyze والاختبارات وبناء Desktop واختبار عقد JSON بين المحرر والمترجم. لا تُغلق أي Issue إلا بعد تنفيذ معايير القبول وخطة الاختبار المكتوبة فيها.

## الحالة الحالية وبنية النظام

يتكون التطبيق من واجهة Flutter في `lib/` ومترجم مستقل في `packages/compiler_c/`، مع نماذج عقد JSON المشتركة في `packages/compiler_contracts/`. يشغّل التطبيق executable باسم `arabicc` عبر JSON Protocol الإصدار `0.5.0`. يتضمن المترجم مراحل Lexer وParser/AST والتحليل الدلالي و3AC وTyped IR وInterpreter وتوليد Assembly نصية. كما يستطيع backend المكتوب بـC إنشاء artifacts تنفيذية لبعض التركيبات المدعومة عند طلب target باسم `dart-native`؛ هذا الاسم هو قيمة في البروتوكول وليس backend مكتوبًا بلغة Dart، والتغطية محدودة بما تثبته اختبارات المترجم.

تبدأ دورة التطبيق من `lib/main.dart`، ويجهز `ServiceLocator` repositories والخدمات، ثم توجه `AppRouter` إلى `EditorShell`. ينسق `EditorController` حالات workspace والوثائق وطلبات compiler؛ تنفذ repositories عمليات الملفات وتشغيل `arabicc`؛ ويرجع compiler النتائج كـJSON للتحقق منها وعرضها عبر لوحات المحرر. يشرح [دليل خريطة الشيفرة](docs/architecture/project-code-map.md) الشجرة المفصلة ومسؤولية الملفات والدوال والأدوات والمكتبات واختبار كل طبقة.

يحتوي المحرر على workspace وشجرة ملفات وتبويبات وتحرير وحفظ وتنسيق وتشخيصات وإصلاحات محدودة وcompletion وhelp وghost text وتلوين معجمي مع تحسين دلالي محدود وMinimap واختصارات التحرير والثيمات ولوحات نتائج المترجم. توجد أمثلة يستهلكها الاختبار في `examples/manual/` وأمثلة إضافية في `examples/` و`examples/errors/`.

مخرجات حقل `assembly` نصية وليست ملفًا تنفيذيًا بحد ذاتها. إنشاء artifact فعلي يتم عبر backend المترجم عند تحديد target مدعوم، ولا يعني ذلك دعم جميع قواعد اللغة.

## بناء المترجم المستقل

يتطلب بناء `arabicc` وجود CMake وFlex وBison ومترجم C متوافق. على Linux وmacOS:

```sh
cd packages/compiler_c
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

وعلى Windows باستخدام Visual Studio:

```powershell
cd packages/compiler_c
cmake -S . -B build
cmake --build build --parallel --config Release
```

يتم توليد scanner الخاص بـ Flex في Windows بوضع `wincompat` لتجنب الاعتماد على `unistd.h`، كما أن الكود يستخدم نسخًا نصية محمولة ومتوافقة مع C17 وMSVC. بعد البناء يمكن اختبار عقد البروتوكول عبر:

```sh
dart run tool/verify_compiler_bundle.dart --executable packages/compiler_c/build/arabicc
```

يمر توليد Assembly الآن عبر 3AC صريح: `Parser/AST → Semantic → TAC → NASM x86_64`. لا يقرأ backend AST مباشرة؛ نفس قائمة 3AC التي تظهر في `threeAddressCode` تُترجم إلى Assembly، بما في ذلك التعبيرات typed، الإدخال، النصوص، الحقيقية، المنطقيات، والفروع المتداخلة.

يتم نشر صورة بيئة التطوير تلقائيًا إلى `ghcr.io/emran025/acsys360/dev:latest` عند الدفع إلى الفرع الرئيسي.

## بناء نسخة Windows نهائية محليًا

يمكن بناء نسخة Windows كاملة من جذر المشروع باستخدام PowerShell. يتطلب السكربت Flutter وDart وCMake وVisual Studio مع أدوات C وInno Setup 6، إضافة إلى Flex وBison. كما يتطلب MSYS2 UCRT64 المثبّت فيه GCC وNASM لتضمينهما في المُثبّت النهائي. يمكن تثبيت Flex وBison عبر Chocolatey:

```powershell
choco install winflexbison3 --yes
```

بعدها شغّل:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows_release.ps1
```

ينفذ السكربت `flutter pub get` و`dart format` و`flutter analyze` و`flutter test`، ثم يبني `arabicc.exe` عبر CMake، ويبني المحرر بـ `flutter build windows --release`، ويضمّن المترجم ومجلد MSYS2 UCRT64 داخل التطبيق. بعد ذلك يشغّل smoke test للبروتوكول وينشئ مُثبّت Windows تنفيذيًا:

```text
dist\acsys360-windows-<version>-setup-x64.exe
```

لإعادة البناء من الصفر:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows_release.ps1 -Clean
```

يمكن تجاوز فحوص Dart/Flutter فقط عند الحاجة إلى تصحيح سريع للبناء، وليس كفحص إصدار نهائي:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows_release.ps1 -SkipChecks
```

إذا أردت مجلد ملفات البناء دون إنشاء مُثبّت، استخدم `-SkipInstaller`؛ لا ينشئ مسار الإصدار المنشور ملفات ZIP أو TAR.

## بناء compiler محليًا مع نسخة Windows Debug

لتوليد `arabicc.exe` من الكود الحالي ونسخه إلى المسار الذي يستخدمه التطبيق المحلي، شغّل من جذر المشروع في PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows_debug.ps1 -Run
```

ينتج السكربت الملف التالي:

```text
build\windows\x64\runner\Debug\compiler\arabicc.exe
```

يتطلب ذلك وجود CMake وVisual Studio C++ وFlex/Bison وFlutter في `PATH`.
