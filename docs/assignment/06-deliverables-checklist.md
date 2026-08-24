# 06 — قائمة التسليم النهائية

## 1. ملفات التوثيق

| المطلوب | الملف |
|---|---|
| وصف التكليف والنطاق | [01-requirements.md](01-requirements.md) |
| المعمارية وتنظيم الطبقات | [02-architecture.md](02-architecture.md) |
| القواعد ومراحل المترجم | [03-language-and-compiler.md](03-language-and-compiler.md) |
| مواصفة المحرر والتفاعلات | [04-editor-behavior.md](04-editor-behavior.md) |
| الاختبارات والبناء والإصدارات | [05-testing-and-build.md](05-testing-and-build.md) |
| فهرس الوثائق | [README.md](README.md) |

## 2. مخرجات المشروع

| المخرج | مكانه أو طريقة التحقق |
|---|---|
| عشرة أمثلة عربية | مجلد `examples/` من `01_arithmetic.arb` إلى `10_combined.arb` |
| compiler executable المضمّن | داخل حزمة Desktop في `compiler/arabicc` أو `compiler/arabicc.exe` |
| Dart SDK للـ native target | داخل release في `compiler/dart-sdk` |
| نتائج lexer/parser/semantic/TAC/assembly/execution | استجابة protocol ولوحة نتائج المحرر |
| artifact الناتج | قائمة `artifacts` بعد نجاح `target: dart-native` فقط |
| شجرة الملفات | `WorkspaceExplorer` مع اختيار Workspace حقيقي |
| التلوين | `ArabicCodeController.buildTextSpan` وتصنيف token colors |
| indentation | Enter الذكي وformatter الصريح |
| الاختصارات | `docs/architecture/editor-shortcuts.md` واختبارات widget المرتبطة |

## 3. قائمة التحقق قبل التسليم

- [ ] القواعد المستخدمة في الأمثلة مطابقة لملف قواعد اللغة.
- [ ] لا توجد صياغة C-like غير موثقة داخل الأمثلة أو الوثائق.
- [ ] كل مرحلة compiler تنتج بيانات من المصدر الحقيقي.
- [ ] الأخطاء تحمل المرحلة والرسالة والموضع المناسب.
- [ ] native artifact موجود وقابل للتشغيل في الحالات التي يعلنها backend.
- [ ] فشل native build يعيد diagnostic ولا يعيد مسارًا وهميًا.
- [ ] الكتابة بحرف جديد أثناء وجود ghost text لا تستهلك الحرف.
- [ ] الأسهم وHome وEnd لا تعيد المؤشر إلى الاتجاه المعاكس أو نهاية البرنامج.
- [ ] Enter يحافظ على indentation ويضع المؤشر بعد السطر الجديد.
- [ ] الألوان المتعددة ظاهرة دون تغيير النص الحقيقي.
- [ ] شعار Arabic360 ظاهر على ملفات `.arb` بعد تسجيل asset.
- [ ] `flutter analyze` و`flutter test` وdesktop build ناجحة في CI.
- [ ] حزمة الوثائق داخل `docs/assignment/` جاهزة للتحويل إلى Word.

## 4. ملاحظة التسليم

تُسلَّم ملفات Markdown كما هي، ويمكن تحويل كل ملف إلى Word مع الحفاظ على العناوين والجداول والشيفرات. لا تُدمج الوثائق في ملف واحد قبل المراجعة حتى يبقى كل محور قابلًا للتتبع والتحديث.
