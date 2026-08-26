# حالة أوامر المحرر وخدمة اللغة

## الغرض

تحدد هذه الوثيقة السلوك الذي يمكن للمستخدم الاعتماد عليه حاليًا في محرر Arabic360، وتفصل بين طبقة التحرير الفورية وطبقة compiler-backed language service. لا تُعرض ميزة على أنها مكتملة إلا إذا كان لها تنفيذ واختبار مناسب، ولا تُنقل مسؤولية Parser أو Semantic Analyzer إلى واجهة Flutter.

## مصفوفة الأوامر الحالية

| المجال | الأمر | التنفيذ الحالي | معيار السلوك |
|---|---|---|---|
| التعديل | Ctrl/Cmd+Z وCtrl/Cmd+Y | undo/redo داخل Document | تعديل واحد قابل للعكس، دون نقل المؤشر إلى نهاية الملف |
| التعليق | Ctrl/Cmd+/ | `ToggleLineComment` | يستخدم `//` فقط، يحافظ على indentation واتجاه التحديد، ويتعامل مع الأسطر الفارغة |
| المسافة | Tab وShift+Tab | indentation وoutdent | لا يُبتلع Tab إلا عند وجود أمر تحرير مؤكد أو اقتراح inline صالح |
| الإكمال | Tab وEscape وUp/Down | ghost completion ودورة عناصر المساعدة | ghost لا يغير المصدر، والكتابة المختلفة تُدخل الحرف مرة واحدة وتلغي الاقتراح القديم |
| الملف | Ctrl/Cmd+S وCtrl/Cmd+Shift+S | حفظ وحفظ باسم | يمر التعديل والحفظ عبر controller وrepository |
| البحث | Ctrl/Cmd+F وCtrl/Cmd+H | شريط البحث والاستبدال | الانتقال والاستبدال لا يغيران النص خارج النطاق المقصود |
| التكبير | Ctrl/Cmd+Plus/Minus | `MediaQuery.textScaler` عام | المقياس محصور بين 0.8 و1.8 ويطبق مرة واحدة على النصوص |
| إعادة المقياس | Ctrl/Cmd+0 | إعادة المقياس إلى 100% | لا يترك fontScale إضافيًا داخل TextField أو gutter |

الاختصارات التي تظهر في المصفوفة العامة بوصفها «مرحلة تالية» لا ينبغي تقديمها للمستخدم على أنها منفذة. ويشمل ذلك تحديد مواقع الرموز، وإعادة التسمية الدلالية، وإدارة chord commands، ونقل الأسطر المتقدم إذا لم يثبتها اختبار مستقل.

## طبقة التلوين

يبدأ التلوين من `Lexer` الفعلي في `compiler_core`، ثم تتحول أنواع `TokenKind` إلى `SourceTokenKind` مستقل عن Flutter. تطبق الواجهة ألوانًا متعددة للكلمات المحجوزة والقيم المنطقية والأعداد والخيوط والمحارف والعمليات وعلامات الترقيم والتعليقات. ولذلك لا توجد قائمة Regex ثانية داخل Widget تعيد تعريف grammar.

تأتي الأدوار الدلالية، عندما تتوفر نتيجة compilation، كتحسين خفيف فوق التلوين المعجمي. الأدوار الحالية هي constant وtype وprocedure وparameter وvariable. هذه الخريطة تعتمد الاسم العام للرمز، ولذلك لا تدعي حل shadowing أو توفير F12 أو F2؛ تحقيق ذلك يتطلب spans ومواقع AST وcontract language-service حقيقيًا.

> عند فشل Parser أو Semantic Analyzer، يبقى التلوين المعجمي ظاهرًا. التشخيص يضيف underline متموجًا ولونًا ذا أولوية على لون token، لكنه لا يستبدل النص ولا يعطل الكتابة.

## قواعد RTL والإدخال

واجهة التطبيق والشجرة واللوحات موجهة من اليمين إلى اليسار. مساحة إدخال الشفرة تستخدم `TextDirection.rtl` مع `TextAlign.right` حتى يتحرك caret مع الإدخال العربي بدل بقائه عند الحافة اليمنى. يحافظ `TextEditingValue` على المواضع المنطقية للنص المختلط، ويظهر `gutter` أرقام الأسطر إلى يمين مساحة الكود، بينما تبقى Minimap إلى يسارها. هذا السلوك يختبر الأسهم وHome وEnd وEnter بدل افتراض أن محاذاة السطر وحدها تكفي.

يجب ألا يعيد التحليل أو completion تعيين `TextEditingValue` أثناء كل ضغطة إلا عند وجود تغيير مصدر مقصود. قبل أي نتيجة غير متزامنة يُلتقط generation للوثيقة، وتُهمل النتيجة القديمة إذا تغير النص. وعند رفض ghost suggestion يجب أن يمر الحرف الجديد إلى TextField مرة واحدة فقط، لا أن يستخدم الرفض مسار إدخال ثانٍ.

## بوابة الإثبات

| السلوك | الاختبار المطلوب |
|---|---|
| التلوين | اختبار أنواع token، comment داخل وخارج string، semantic role، وأولوية diagnostic |
| التعليق | اختبار السطر الحالي، التحديد متعدد الأسطر، selection العكسي، الأسطر الفارغة، وفك التعليق |
| التكبير | اختبار اختصارات plus/minus/zero في shell، والتحقق من عدم مضاعفة حجم TextField |
| RTL | اختبار اتجاه TextField، النص المختلط، الأسهم، Home/End، Enter، موضع caret، وترتيب gutter/Minimap |
| formatter | اختبار عدم لمس محتوى string/character/comment، وتوازن الأقواس والإزاحة |

تظل Assembly المعروضة مخرجًا أكاديميًا نصيًا ما لم تمر عبر assembler فعلي، وتظل native artifact مرتبطة بالتركيبات التي يغطيها backend واختبارات التشغيل. هذه الوثيقة لا توسع حدود compiler أو language service بمجرد إضافة واجهة عرض.

## المراجع

[1]: https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide "VS Code Syntax Highlight Guide"

[2]: https://code.visualstudio.com/api/language-extensions/semantic-highlight-guide "VS Code Semantic Highlight Guide"

[3]: https://code.visualstudio.com/api/language-extensions/language-configuration-guide "VS Code Language Configuration Guide"
