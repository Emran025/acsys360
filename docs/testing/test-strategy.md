# استراتيجية الاختبار

## الاختبارات الموجودة حاليًا

| الحزمة/الطبقة | موضع الاختبارات وما تغطيه |
|---|---|
| تطبيق Flutter | `test/`: وحدات للمستندات وworkspace، المحرر وخدمات اللغة، التنسيق والبحث والتعليق، المستودعات المحلية، مسارات الملفات، والاتصال بعملية compiler. يتضمن `test/widget_test.dart` اختبارات واجهة للـrouting، workspace الترحيبي، لوحات النتائج، RTL والمؤشر، Minimap، themes، completion، الاختصارات والتشخيصات |
| عقد JSON | `packages/compiler_contracts/test/`: اختبارات compilation وassist requests/responses |
| مترجم C | `packages/compiler_c/tests/` وCTest: فحوص تشغيل `--version` و`--help`، golden tests لـTAC وAssembly، smoke لـnative 3AC، واختبار أمان artifact |
| تكامل المترجم | اختبارات Dart المسجلة في CMake عند توفر Dart: protocol smoke، الأمثلة اليدوية، قاعدة الفاصلة المنقوطة، الأنواع المركبة، والاستقرار |
| CI | `.github/workflows/ci.yml`: تحليل واختبار العقود، بناء C وتشغيل CTest، تنسيق وتحليل واختبار Flutter، ثم بناء Linux Desktop |

## Fixtures

توجد الأمثلة اليدوية المرقمة في `examples/manual/`، وأمثلة أخرى في `examples/`، وملفات الأخطاء في `examples/errors/`. لا تستخدم الشجرة الحالية مجلدات `examples/valid/` أو `examples/syntax-errors/` أو `examples/semantic-errors/`؛ تُضاف أي أمثلة جديدة إلى التنظيم الموجود مع تحديث الاختبارات التي تستهلكها.

## معايير الجودة

استخدم أوامر CI الموجودة للتحقق من التغيير: `flutter analyze` و`flutter test` لتطبيق Flutter، و`dart analyze` و`dart test` داخل `packages/compiler_contracts/`، وCMake/CTest داخل `packages/compiler_c/`. يتطلب البناء الكامل للمحرر `flutter build linux --release`. لا تُضف ادعاءات تغطية لمرحلة أو target إلا إذا كانت مثبتة باختبار مناسب؛ Assembly المعادة في البروتوكول نص، وartifact التنفيذي يقتصر على التركيبات التي يقبلها backend.
