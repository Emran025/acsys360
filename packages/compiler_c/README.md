# arabicc — C Compiler Backend

هذا هو backend المستقل للمترجم العربي في `packages/compiler_c`. يستخدم **Flex** للمحلل المعجمي و**GNU Bison** للمحلل النحوي، ويبني executable باسم `arabicc` يتصل بتطبيق Flutter عبر JSON Protocol الإصدار `0.5.0`.

## المتطلبات

### Windows

يعمل البناء الرسمي باستخدام Visual Studio و`winflexbison3`:

```powershell
choco install winflexbison3 --yes
```

يمكن استخدام MSYS2 أو MinGW عند الحاجة إلى أدوات C إضافية، لكن workflow الرسمي يستخدم MSVC على `windows-latest`.

### Linux

```sh
sudo apt update
sudo apt install -y build-essential flex bison cmake
```

### macOS

```sh
brew install flex bison cmake
```

## البناء عبر CMake

من مجلد `packages/compiler_c`:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

على Windows باستخدام Visual Studio:

```powershell
cmake -S . -B build
cmake --build build --parallel --config Release
ctest --test-dir build -C Release --output-on-failure
```

الناتج هو:

```text
Linux/macOS: build/arabicc
Windows:     build/Release/arabicc.exe
```

يستخدم `CMakeLists.txt` خيار Flex `--wincompat` على Windows حتى لا يضيف scanner الناتج اعتمادًا على `unistd.h` غير المتوفرة مع MSVC. كما يستخدم `lexer.l` دالة نسخ نصية محمولة متوافقة مع C17 بدل `strdup`.

## الأوامر التشغيلية

```sh
./build/arabicc --version
./build/arabicc --help
```

في Windows:

```powershell
.\build\Release\arabicc.exe --version
.\build\Release\arabicc.exe --help
```

لتشغيل بروتوكول JSON، أرسل الطلب إلى stdin باستخدام `--protocol`:

```sh
printf '%s\n' '{"protocolVersion":"0.5.0","rootPath":"/tmp","sourcePaths":[],"sourceTexts":{},"mode":"project"}' | ./build/arabicc --protocol
```

عند تمرير `target: "dart-native"` مع `artifactDirectory`، يتولى backend
نفسه كتابة Assembly وتشغيل NASM وGCC وإرجاع مساري ملف `.asm` وملف التنفيذ
ضمن `artifacts`. لا يقوم تطبيق Flutter ببناء Assembly أو إدارة NASM/GCC؛
وظيفته تقتصر على إرسال الطلب وتشغيل artifact الذي أعاده backend.

يدعم مولّد NASM الحالي في مسار `dart-native` الأنواع `صحيح` و`حقيقي`
و`منطقي` و`حرفي` و`خيط_رمزي`، مع الإدخال والإخراج والثوابت والتعبيرات
الحسابية الأساسية. ينتج كل بناء Windows ملف تنفيذ باسم فريد يتضمن معرّف
عملية المترجم، حتى لا يفشل البناء عند بقاء artifact سابق قيد التشغيل
ومقفولاً من النظام.

ويتحقق اختبار التكامل من executable المضمن داخل تطبيق Desktop:

```sh
dart run tool/verify_compiler_bundle.dart --executable build/arabicc
```

## بنية المجلد

| المسار | المسؤولية |
|---|---|
| `src/lexer.l` | قواعد Flex للرموز والكلمات العربية ومواقعها |
| `src/parser.y` | قواعد Bison وبناء AST |
| `src/protocol.c` | قراءة JSON request، بناء artifact native، وتجميع JSON response |
| `src/main.c` | نقطة التشغيل ومعالجة `--protocol` و`--assist` و`--version` و`--help` |
| `src/ast.c` | عقد AST والتسلسل المرتبط بها |
| `src/semantic.c` | الرموز والتحقق الدلالي المحدود |
| `src/backend/x86_64/asm_x86_64.c` | تنسيق توليد NASM والواجهة العامة مع الحفاظ على المسار AST + Semantic Result → Assembly |
| `src/backend/x86_64/asm_x86_64_internal.h` | عقد داخلي وسياق التوليد المشترك بين وحدات backend |
| `src/backend/x86_64/asm_x86_64_context.c` | مخزن النصوص، إدارة الذاكرة، التشخيصات، والبحث في الرموز |
| `src/backend/x86_64/asm_x86_64_literals.c` | جمع النصوص والأعداد الحقيقية وإخراج قيم `.data` بصيغة NASM |
| `src/backend/x86_64/asm_x86_64_expressions.c` | فحوص الأنواع وتوليد تعليمات التعبيرات integer/real/text |
| `src/backend/x86_64/asm_x86_64_statements.c` | توليد الفروع والإسناد والطباعة ضمن الكتل المتداخلة |
| `src/backend/x86_64/asm_x86_64_frame.c` | حساب إطار المكدس وإخراج المقدمة والخاتمة |
| `include/*.h` | عقود البيانات وواجهات الوحدات |
| `CMakeLists.txt` | توليد parser/scanner وبناء `arabicc` واختبارات CMake |

## التكامل مع التطبيق

يبدأ تطبيق Flutter العملية من data layer عبر `ProcessCompilerRepositoryImpl`. يكتب الطلب إلى stdin، يقرأ الاستجابة من stdout، ثم يحولها عبر `packages/compiler_contracts` إلى كيانات domain. لا يعتمد `arabicc` على Flutter، ولا يجب أن تستدعي Widgets parser أو filesystem مباشرة.

## References

[1]: https://github.com/Emran025/acsys360/blob/main/packages/compiler_c/CMakeLists.txt "arabicc CMake configuration"
[2]: https://github.com/Emran025/acsys360/blob/main/packages/compiler_c/src/lexer.l "Arabic Flex lexer"
[3]: https://github.com/Emran025/acsys360/blob/main/packages/compiler_c/src/parser.y "Arabic Bison parser"
[4]: https://github.com/Emran025/acsys360/blob/main/.github/workflows/release.yml "Cross-platform release workflow"

المراجع: [1] [2] [3] [4]
