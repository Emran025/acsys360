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
| عشرة أمثلة عربية | مجلد `examples/` من `01_arithmetic.arb` إلى `10_combined.arb`، مع `examples/errors/` للنتائج السلبية |
| compiler executable المضمّن | داخل حزمة Desktop في `compiler/arabicc` أو `compiler/arabicc.exe` |
| Dart SDK للـ native target | داخل release في `compiler/dart-sdk` |
| نتائج lexer/parser/semantic/TAC/assembly/execution | استجابة protocol ولوحة نتائج المحرر |
| artifact الناتج | قائمة `artifacts` بعد نجاح `target: dart-native` فقط |
| شجرة الملفات | `WorkspaceExplorer` مع اختيار Workspace حقيقي |
| التلوين | `ArabicCodeController.buildTextSpan` وتصنيف token colors |
| indentation | Enter الذكي وformatter الصريح |
| الاختصارات | `docs/architecture/editor-shortcuts.md` واختبارات widget المرتبطة |

## 3. قائمة التحقق قبل التسليم

- [x] القواعد المستخدمة في الأمثلة مطابقة لملف قواعد اللغة.
- [x] لا توجد صياغة C-like غير موثقة داخل الأمثلة أو الوثائق.
- [x] كل مرحلة compiler تنتج بيانات من المصدر الحقيقي.
- [x] الأخطاء تحمل المرحلة والرسالة والموضع المناسب.
- [x] native artifact موجود وقابل للتشغيل في الحالات التي يعلنها backend.
- [x] فشل native build يعيد diagnostic ولا يعيد مسارًا وهميًا.
- [x] الكتابة بحرف جديد أثناء وجود ghost text لا تستهلك الحرف.
- [x] الأسهم وHome وEnd لا تعيد المؤشر إلى الاتجاه المعاكس أو نهاية البرنامج.
- [x] Enter يحافظ على indentation ويضع المؤشر بعد السطر الجديد، بما في ذلك offset صفر.
- [x] الألوان المتعددة ظاهرة دون تغيير النص الحقيقي.
- [x] شعار Arabic360 ظاهر على ملفات `.arb` بعد تسجيل asset.
- [x] execution output متعدد الأسطر يُعرض بفواصل فعلية داخل لوحة النتائج.
- [x] compile وcompletion وhelp لا تطبق نتائج snapshot قديم بعد edit أحدث.
- [x] `flutter analyze` و`flutter test` وdesktop build ناجحة في CI.
- [x] حزمة الوثائق داخل `docs/assignment/` جاهزة للتحويل إلى Word.

## 4. ملاحظة التسليم

تُسلَّم ملفات Markdown كما هي، ويمكن تحويل كل ملف إلى Word مع الحفاظ على العناوين والجداول والشيفرات. لا تُدمج الوثائق في ملف واحد قبل المراجعة حتى يبقى كل محور قابلًا للتتبع والتحديث.
