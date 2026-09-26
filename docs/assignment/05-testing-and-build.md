# 05 — الاختبارات والبناء والتسليم

## 1. طبقات الاختبار

| الطبقة | ما تثبته |
|---|---|
| Lexer tests | تصنيف الكلمات والرموز والأعداد والخيوط والمحارف والتعليقات والأخطاء غير المغلقة |
| Parser tests | إنتاج AST للتعريفات والتعليمات والتعبيرات والوصول والحلقات والاستدعاءات |
| Domain/editor tests | document/workspace، controller والطلبات غير المتزامنة، تنسيق وبحث وتعليق، repositories ومسارات الملفات |
| Flutter widget tests | routing، workspace الترحيبي، لوحات النتائج، RTL والمؤشر، Minimap، themes، completion، indentation، الاختصارات والتشخيصات |
| Protocol contract tests | compilation وassist request/response في `packages/compiler_contracts/test/` |
| C backend tests | CTest: تشغيل executable، golden tests لـTAC وAssembly، native 3AC smoke، واختبار artifact security |
| Compiler integration | protocol smoke، الأمثلة اليدوية، قاعدة الفاصلة المنقوطة، الأنواع المركبة، والاستقرار؛ تسجل عبر CMake عند توفر Dart |
| CI build | تحليل واختبار العقود، بناء C وتشغيل CTest، format/analyze/test للتطبيق، وبناء Flutter Linux |

## 2. أمثلة اللغة وحدود التغطية

تقع الأمثلة اليدوية المرقمة في `examples/manual/`، وتوجد ملفات أخطاء في `examples/errors/`. لا يعني وجود مثال أو مرحلة في JSON أن كل صيغ اللغة مدعومة؛ تُذكر التغطية وفق اختبارات المترجم في `packages/compiler_c/tests/` ونتائج CI. target `dart-native` قيمة بروتوكول يستخدمها backend المكتوب بلغة C لإنشاء artifact ضمن مجموعة التركيبات المدعومة، وليس مترجم Dart منفصلًا.

## 3. فحوص الجودة

يجب أن ينجح داخل تطبيق Flutter:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux --release
```

وتُختبر حزمة العقد والمترجم منفصلتين:

```sh
cd packages/compiler_contracts
dart analyze
dart test

cd ../compiler_c
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

تستخدم GitHub Actions Flutter `3.44.5` وDart `3.12.2` وفق `.github/workflows/ci.yml`. لا يُستعاض عن الفحوص غير المتاحة محليًا بادعاء نجاحها؛ يذكر القيد وتُراجع نتيجة CI.

## 4. البناء والنشر

يُبنى `packages/compiler_c/` عبر CMake وFlex وBison. يحدد Workflow الإصدار مسارات التغليف ويشغّل اختبارات bundle قبل نشر ملفات المنصات؛ أما CI الرئيسي الحالي فيتحقق من بناء Linux Desktop. راجع workflow الإصدار لمعرفة التوزيعات الفعلية وتفاصيل مكان executable.

## 5. معايير قبول الإصدار

لا يصدر tag جديد إذا كان format أو analyze أو test أو desktop build فاشلًا. لا تعاد قائمة `artifacts` عند فشل البناء أو عدم وجود الملف. لا تُحذف tags السابقة، ولا يعاد استخدام tag منشور لمحتوى مختلف؛ كل تغيير جوهري يأخذ إصدارًا جديدًا.

## 6. سجل التحقق الحالي

| العنصر | الحالة المثبتة |
|---|---|
| protocol `0.5.0` | العقد معرّف في `packages/compiler_contracts` والمترجم C في `packages/compiler_c` |
| typed IR | مخرج من compiler C ويظهر ضمن بروتوكول النتائج |
| C executable | يُبنى باسم `arabicc`؛ دعم التركيبات محكوم باختبارات backend |
| اختبارات Flutter | موجودة في `test/` وتشمل اختبارات وحدات وWidgets |
| CI | راجع `.github/workflows/ci.yml` للحالة والبوابات الحالية |
| Assembly | النص في الاستجابة ليس binary؛ إنشاء artifact المنفصل متاح عبر target مدعوم |
