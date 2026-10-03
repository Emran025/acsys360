# استراتيجية الاختبار

## شجرة الاختبارات

تعكس شجرة `test/` طبقات Clean Architecture: `core/`، ثم `features/editor/domain` للكيانات والخدمات وuse cases، ثم `data/repositories_impl`، ثم `presentation/controllers` و`presentation/ui`، وأخيرًا `integration/` لحدود العمليات الخارجية. أما `packages/compiler_c/tests/` فتقسم إلى `unit/` و`security/` و`integration/`، وجميعها مسجلة في CTest. يوجد وصف مختصر في `test/README.md` و`packages/compiler_c/tests/README.md`.

## الاختبارات الموجودة حاليًا

| الحزمة/الطبقة | موضع الاختبارات وما تغطيه |
|---|---|
| تطبيق Flutter | `test/core/` و`test/features/editor/`: اختبارات الوحدات مرتبة حسب طبقات Clean Architecture، و`test/integration/compiler/` لاختبار حدود عملية compiler. اختبار الواجهة موجود في `test/features/editor/presentation/ui/widget_test.dart` ويغطي routing وworkspace واللوحات وRTL وMinimap وthemes وcompletion والاختصارات والتشخيصات |
| عقد JSON | `packages/compiler_contracts/test/`: اختبارات compilation وassist requests/responses |
| مترجم C | `packages/compiler_c/tests/unit/` و`security/` و`integration/` عبر CTest: فحوص التشغيل، golden tests لـTAC وAssembly، smoke لـnative 3AC، واختبار أمان artifact |
| تكامل المترجم | اختبارات Dart المسجلة في CMake عند توفر Dart: protocol smoke، الأمثلة اليدوية، قاعدة الفاصلة المنقوطة، الأنواع المركبة، والاستقرار |
| CI | `.github/workflows/ci.yml`: تحليل واختبار العقود، بناء C وتشغيل CTest، تنسيق وتحليل واختبار Flutter، ثم بناء Linux Desktop |

## التغطية

يُقاس coverage عبر `flutter test --coverage`، وتوجد آخر نتيجة والفجوات المعروفة في `docs/testing/coverage-baseline.md`. النسبة ليست بديلًا عن اختبارات سلوكية لحالات الفشل والتكامل.

## Fixtures

توجد الأمثلة اليدوية المرقمة في `examples/manual/`، وأمثلة أخرى في `examples/`، وملفات الأخطاء في `examples/errors/`. لا تستخدم الشجرة الحالية مجلدات `examples/valid/` أو `examples/syntax-errors/` أو `examples/semantic-errors/`؛ تُضاف أي أمثلة جديدة إلى التنظيم الموجود مع تحديث الاختبارات التي تستهلكها.

## معايير الجودة

استخدم أوامر CI الموجودة للتحقق من التغيير: `flutter analyze` و`flutter test` لتطبيق Flutter، و`dart analyze` و`dart test` داخل `packages/compiler_contracts/`، وCMake/CTest داخل `packages/compiler_c/`. يتطلب البناء الكامل للمحرر `flutter build linux --release`. لا تُضف ادعاءات تغطية لمرحلة أو target إلا إذا كانت مثبتة باختبار مناسب؛ Assembly المعادة في البروتوكول نص، وartifact التنفيذي يقتصر على التركيبات التي يقبلها backend.
