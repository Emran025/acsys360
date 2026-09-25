# acsys360 — محرر ومترجم اللغة العربية

هذا المستودع هو نقطة البداية لبناء محرر لغة مكتبي شبيه بـ VS Code ومترجم مستقل للغة البرمجة العربية المحددة في ملفات المقرر. المشروع يتجه إلى Flutter Desktop، مع فصل Clean Architecture بين الواجهة، منطق المحرر، البنية التحتية، ونواة المترجم.

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
| `docs/architecture/product-boundary.md` | ما يدخل في النطاق وما يبقى خارج الادعاء |
| `docs/architecture/editor-shortcuts.md` | مصفوفة أوامر المحرر واختبارها |
| `docs/assignment/12-code-component-guide.md` | سبب وجود كل مكون ومسار بياناته وحدوده |
| `docs/roadmap/roadmap.md` | مراحل البناء ومعايير الانتقال |
| `docs/testing/test-strategy.md` | اختبارات كل مرحلة ومعايير الجودة |
| `.github/workflows/ci.yml` | بوابة CI وبناء Desktop |
| `CHANGELOG.md` | سجل الإصدارات وملاحظات البناء |

## المنتج المستهدف

يقدم المحرر مستكشف ملفات، مجلد workspace، تعدد الملفات والتبويبات، تحرير RTL، اختصارات، command palette، بحث واستبدال، تنسيق، themes، Undo/Redo transaction-based، تشخيصات، تشغيل وإيقاف، ولوحات Tokens وAST وSymbol Table وSemantic Diagnostics وTAC وAssembly وRuntime Output.

## أسلوب العمل

يُبنى كل تغيير في فرع مستقل ويُدمج عبر Pull Request بعد نجاح format وanalyze والاختبارات وبناء Desktop واختبار عقد JSON بين المحرر والمترجم. لا تُغلق أي Issue إلا بعد تنفيذ معايير القبول وخطة الاختبار المكتوبة فيها.

## الحالة الحالية

المستودع يحتوي على محرر Flutter Desktop ومترجم `compiler_core` مستقل يتواصل مع المحرر عبر JSON protocol الإصدار `0.5.0`. تدعم النواة Lexer وParser/AST والتحليل الدلالي وSymbol Table وTAC وTyped IR وAssembly النصية وInterpreter، إضافة إلى backend `dart-native` محدود ومثبت باختبارات parity وartifact metadata.

يحتوي المحرر على workspace حقيقي وشجرة ملفات وتبويبات وتحرير وحفظ وتنسيق وتشخيصات وquick fixes محدودة وcompletion وhelp وghost text وsyntax/semantic highlighting وMinimap واختصارات التحرير وthemes ونتائج مراحل المترجم. توجد عشرة أمثلة نجاح مختلفة في `examples/`، وfixtures سلبية مستقلة في `examples/errors/` لاختبار syntax وsemantic diagnostics.

الإصدار الحالي هو [`v0.0.3`](https://github.com/Emran025/acsys360/releases/tag/v0.0.3)، ويشمل تحسينات محرر RTL، وإلزام الفاصلة المنقوطة العربية، وإصلاح بناء Windows، إضافة إلى قواعد المترجم العربي الأساسية وتحسين AST ومخرجات بروتوكول compiler. لا تُسمى Assembly binary، ولا يُعلن `dart-native` مترجمًا عامًا لكل قواعد اللغة؛ كلا الحدين موثق ومغطى فقط ضمن subset المثبت.

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
