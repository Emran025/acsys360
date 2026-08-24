# نتائج دراسة سلوك VS Code

## مصادر رسمية

1. [IntelliSense](https://code.visualstudio.com/docs/editing/intellisense) يعرّف الإكمال كميزة مستقلة عن إدخال النص، ويعرض الاقتراحات السياقية مع أوامر قبول واضحة.
2. [Language Configuration Guide](https://code.visualstudio.com/api/language-extensions/language-configuration-guide) يحدد أن تجربة التحرير لا تقتصر على التلوين، بل تشمل brackets، autoclosing، autosurrounding، folding، word pattern، indentation rules، وon-enter rules.
3. [Syntax Highlight Guide](https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide) يقرر أن التلوين يعتمد على grammar تصنف الكلمات المحجوزة والأنواع والقيم والعوامل والتعليقات إلى scopes مستقلة.
4. [Basic Editing](https://code.visualstudio.com/docs/editing/codebasics) يوثق عمليات التحرير الأساسية وحركة المؤشر والتحديد والتحرير متعدد الأسطر.

## قواعد تنفيذية مستخلصة

| المجال | السلوك المطلوب في Arabic360 |
|---|---|
| رفض الاقتراح | الحرف الذي يكتبه المستخدم ليس أمر رفض؛ يجب أن يمر إلى TextField مرة واحدة، بينما يُغلق النص الشبح بعد وصول التغيير إلى onChanged. |
| قبول الاقتراح | Tab يقبل الاقتراح فقط عند وجوده، ولا يغير النص قبل ذلك. Escape يغلق الاقتراح دون تعديل المصدر. |
| الحركة | الأسهم وHome وEnd يجب أن تصل إلى محرر النص ولا تُحتجز بسبب وجود اقتراح. محرر الكود يستعمل اتجاهًا ثابتًا مناسبًا لترتيب المحارف، مع إبقاء واجهة التطبيق RTL. |
| السباق الزمني | نتيجة completion أو التحليل القديمة لا يجوز أن تكتب حالة فوق تحرير أحدث؛ كل طلب يحتاج generation/version check. |
| السطر الجديد | Enter يحافظ على indentation السابقة ويزيد المستوى بعد `{`، ولا ينقل selection إلى نهاية الملف. |
| التلوين | يجب أن تكون الألوان ناتجة عن تصنيف tokens/contexts، لا لونًا واحدًا للنص كله، مع عدم التأثير في النص الفعلي أو selection. |
| التنسيق | formatter منفصل يعيد TextEdit واضحًا، ولا يعمل أثناء كل حرف ولا يعيد ضبط المؤشر دون mapping. |
| الأيقونة | شعار Arabic360 أصل مسجل في assets ويظهر على ملفات `.arb` نفسها داخل الشجرة والتبويبات عند الحاجة. |

## ملاحظة هندسية

لا يكفي وضع ghost text في `TextSpan`؛ يجب الفصل بين النص الحقيقي، النص الشبح، selection، وحالة الطلب غير المتزامن. أي استدعاء يعيد تعيين `TextEditingValue` أثناء onChanged أو callback selection قد يعيد النص السابق ويظهر للمستخدم كأنه يحتاج كتابة الحرف مرتين أو يقفز إلى نهاية الملف.
