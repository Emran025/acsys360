# 06 — قائمة التسليم والأدلة

هذه القائمة تربط عناصر التسليم بمواقعها الحالية. الإشارة إلى ملف أو اختبار لا تعني وحدها اجتياز CI أو نجاح إصدار معين؛ راجع نتيجة التشغيل المناسبة وقت التسليم.

## 1. ملفات التوثيق

| الموضوع | الملف |
|---|---|
| المتطلبات والحدود | [01-requirements.md](01-requirements.md) |
| معمارية التطبيق والمترجم | [02-architecture.md](02-architecture.md) |
| اللغة ومراحل compiler | [03-language-and-compiler.md](03-language-and-compiler.md) |
| سلوك المحرر ومستكشف Workspace | [04-editor-behavior.md](04-editor-behavior.md) |
| الاختبارات والبناء | [05-testing-and-build.md](05-testing-and-build.md) |
| قواعد الجودة | [09-quality-gates.md](09-quality-gates.md) |
| شرح المكونات ومسارات البيانات | [12-code-component-guide.md](12-code-component-guide.md) |
| المعمارية التفصيلية | [../architecture/architecture.md](../architecture/architecture.md) |
| حدود المنتج والحالة | [../architecture/product-boundary.md](../architecture/product-boundary.md) |
| اختصارات المحرر | [../architecture/editor-shortcuts.md](../architecture/editor-shortcuts.md) |

## 2. مخرجات المشروع

| المخرج | المكان أو طريقة التحقق |
|---|---|
| أمثلة اللغة | `examples/manual/01_basics.arb` إلى `10_all_rules.arb`، وأمثلة أخرى في `examples/` وملفات أخطاء في `examples/errors/` |
| تطبيق Flutter | `lib/` مع مجلدات المنصات؛ تحقق التشغيل والتوزيع من CI/workflows المناسبة |
| Compiler executable | `arabicc` أو `arabicc.exe` الناتج من CMake داخل `packages/compiler_c/` أو المضمن في bundle |
| عقد JSON | `packages/compiler_contracts/`، الإصدار `0.5.0` |
| نتائج التحليل | protocol response ولوحات النتائج في المحرر |
| Assembly | نص في حقل `assembly`؛ ليس artifact تنفيذيًا بحد ذاته |
| executable artifact | يعاد ضمن `artifacts` بعد إنشاء حقيقي ونجاح target المدعوم |
| مستكشف Workspace | `WorkspaceExplorer`؛ الأسماء LTR ومحاذاة اليمين ضمن shell RTL |
| اختبارات التطبيق | `test/`، ومنها `test/widget_test.dart` |
| اختبارات compiler والعقد | `packages/compiler_c/tests/` و`packages/compiler_contracts/test/` |

## 3. حالة الإثبات

| المجال | الدليل الموجود | ما يجب التحقق منه عند التسليم |
|---|---|---|
| عقد JSON | نماذج واختبارات compilation/assist | تشغيل اختبارات العقود على التغييرات الحالية |
| compiler C | CMake وCTest واختبارات تكامل مسجلة عند توفر Dart | build نظيف وCTest ومراجعة نتائج الأمثلة |
| محرر Flutter | unit/widget tests في `test/` | `flutter analyze` و`flutter test` |
| Workspace repository | CRUD، path handling، ورفض مسارات خارج الجذر في الاختبارات | إعادة تشغيل الاختبارات بعد تغييرات filesystem |
| Workspace explorer UI | أزرار وقوائم سياق في `workspace_explorer.dart`؛ ليست كل التفاعلات مغطاة بـwidget tests | إضافة/تشغيل regressions للشجرة والقوائم والمحاذاة |
| Desktop builds | CI يبني Linux؛ توجد workflows وسكربتات إصدار | تحقق من سجل workflow وbundle لكل منصة مطلوبة |
| artifact | backend builder واختبارات smoke/security | تشغيل artifact فعليًا للتركيبات المعلنة فقط |

## 4. خطوات تحقق مقترحة للتسليم

1. شغّل تنسيق Dart وتحليل واختبارات Flutter.
2. شغّل تحليل واختبارات `packages/compiler_contracts`.
3. ابنِ `packages/compiler_c` عبر CMake وشغّل CTest.
4. تحقق من bundle وتشغيله لكل منصة تدخل ضمن التسليم.
5. راجع أن كل ادعاء في التقرير يطابق اختبارًا أو قيدًا موثقًا؛ لا تستخدم علامة إنجاز قديمة كبديل عن دليل حديث.

انظر إلى [استراتيجية الاختبار](../testing/test-strategy.md) للأوامر والبوابات الحالية.
