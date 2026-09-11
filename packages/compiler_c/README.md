# arabicc (C Compiler Backend - Flex & Bison)

هذا هو التنفيذ المستقل للمترجم العربي بلغة C المبني باستخدام **Flex** (للمحلل المعجمي) و **GNU Bison** (للمحلل النحوي)، والذي يتصل مباشرة بواجهات محرر Flutter عبر بروتوكول JSON القياسي (`0.5.0`).

---

## 1. المتطلبات البرمجية الأساسية (Prerequisites)

لأي مطور يقوم باستنساخ المشروع (Git Clone) أو للبناء على بيئات مختلفة:

### على نظام Windows:
- **مترجم C**: `gcc` (متوفر عبر [MSYS2](https://www.msys2.org/) أو MinGW أو w64devkit).
- **Flex و Bison**:
  - الخيار 1 (عبر MSYS2 - موصى به):
    ```sh
    pacman -S mingw-w64-ucrt-x86_64-gcc flex bison make cmake
    ```
  - الخيار 2 (عبر Chocolatey):
    ```sh
    choco install winflexbison3 mingw
    ```
  - الخيار 3 (عبر Winget):
    ```sh
    winget install MSYS2.MSYS2
    ```

### على نظام Linux (Ubuntu / Debian):
```sh
sudo apt update
sudo apt install -y build-essential flex bison cmake
```

### على نظام macOS:
```sh
brew install flex bison cmake
```

---

## 2. طرق البناء (Build Instructions)

### الطريقة 1: عبر سكربتات البناء المباشرة (Windows)
تقوم السكربتات باكتشاف الأدوات تلقائياً سواء كانت في مسار النظام `PATH` أو في مسار MSYS2 الافتراضي `C:\msys64`:
```powershell
# عبر PowerShell:
powershell -ExecutionPolicy Bypass -File build.ps1

# أو عبر موجه الأوامر (CMD):
build.bat
```

### الطريقة 2: عبر CMake (متوافق مع جميع المنصات وخوادم CI/CD)
```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

الناتج التنفيذي سيكون في المسار:
- في Windows: `build/arabicc.exe` أو `build/arabicc_c.exe`
- في Linux/macOS: `build/arabicc` أو `build/arabicc_c`

---

## 3. التحقق من عمل المترجم وبروتوكول الواجهات

- التحقق من الإصدار:
  ```sh
  ./build/arabicc.exe --version
  ```
- تشغيل اختبار الدخان المعتمد للنشر (Deploy / Smoke Test):
  ```sh
  dart run ../../tool/verify_compiler_bundle.dart --executable packages/compiler_c/build/arabicc.exe
  ```

---

## 4. هيكل مجلد المترجم
- `src/lexer.l`: مواصفات المحلل المعجمي (Flex) بدعم UTF-8 للحروف والكلمات العربية.
- `src/parser.y`: قواعد الجرامر والإعراب (Bison).
- `src/protocol.c` و `include/protocol.h`: جسر التواصل المعياري بالـ JSON مع محرر Flutter.
- `src/ast.c` و `include/ast.h`: هياكل وإدارة عُقد شجرة الإعراب (AST).
- `src/main.c`: نقطة البداية ومعالجة `--protocol` و `--assist`.
- `legacy_manual/`: أرشيف محاولات بناء المترجم يدوياً قبل الانتقال إلى Flex و Bison.
