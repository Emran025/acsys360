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
| البحث | Ctrl/Cmd+F | فتح/تبديل شريط البحث والاستبدال | لا يوجد binding حالي لـCtrl/Cmd+H |
| التكبير | Ctrl/Cmd+= وCtrl/Cmd+- | `MediaQuery.textScaler` عام | المقياس محصور بين 0.8 و1.8 ويطبق مرة واحدة على النصوص |
| إعادة المقياس | Ctrl/Cmd+0 | إعادة المقياس إلى 100% | لا يترك fontScale إضافيًا داخل TextField أو gutter |
| Compiler | F5 وCtrl/Cmd+F5 | ترجمة/تنفيذ الملف النشط وبناء artifact | artifact يتبع target المدعوم ونتيجة backend الفعلية |
| التنقل | Ctrl/Cmd+PageUp/PageDown وF8/Shift+F8 | تبديل التبويب والتنقل بين التشخيصات | لا يوجد binding حالي لـCtrl/Cmd+1..9 |

لا توجد bindings حاليًا لـCtrl/Cmd+H أو Ctrl/Cmd+B أو Ctrl/Cmd+1..9 أو F2 أو F12 أو Ctrl/Cmd+. المباشر. مصباح التشخيص لا يساوي binding quick-fix. القائمة التفصيلية في [مصفوفة الاختصارات](../architecture/editor-shortcuts.md).

## طبقة التلوين

يبدأ التلوين من نتيجة lexer الفعلي في `packages/compiler_c/src/lexer.l` عند وصول compilation response، ثم تتحول أنواع tokens إلى `SourceTokenKind` مستقل عن Flutter. تطبق الواجهة ألوانًا متعددة للكلمات المحجوزة والقيم المنطقية والأعداد والخيوط والمحارف والعمليات وعلامات الترقيم والتعليقات. ولذلك لا توجد قائمة Regex ثانية داخل Widget تعيد تعريف grammar.

تأتي الأدوار الدلالية، عندما تتوفر نتيجة compilation، كتحسين خفيف فوق التلوين المعجمي. الأدوار الحالية هي constant وtype وprocedure وparameter وvariable. هذه الخريطة تعتمد الاسم العام للرمز، ولذلك لا تدعي حل shadowing أو توفير F12 أو F2؛ تحقيق ذلك يتطلب spans ومواقع AST وcontract language-service حقيقيًا.

> عند فشل Parser أو Semantic Analyzer، يبقى التلوين المعجمي ظاهرًا. التشخيص يضيف underline متموجًا ولونًا ذا أولوية على لون token، لكنه لا يستبدل النص ولا يعطل الكتابة.

## قواعد RTL والإدخال

واجهة التطبيق والشجرة واللوحات موجهة من اليمين إلى اليسار. مساحة إدخال الشفرة تستخدم `TextDirection.rtl` مع `TextAlign.right` حتى يتحرك caret مع الإدخال العربي. في المقابل، أسماء الجذر والملفات والمجلدات داخل `WorkspaceExplorer` تستخدم `TextDirection.ltr` و`TextAlign.right`: يحافظ الاتجاه على ترتيب المسار والامتداد اللاتيني، وتبقي المحاذاة النص ملاصقًا ليمين صف الشجرة. لا ينبغي تعميم اتجاه explorer على محرر الكود. يظهر `gutter` أرقام الأسطر إلى يمين مساحة الكود، بينما تبقى Minimap إلى يسارها.

تتضمن الاختبارات widget حالات RTL والمؤشر والـMinimap، لكنها لا تغطي حاليًا محاذاة نصوص explorer أو قوائم سياقه كاختبارات widget مستقلة.

يجب ألا يعيد التحليل أو completion تعيين `TextEditingValue` أثناء كل ضغطة إلا عند وجود تغيير مصدر مقصود. قبل أي نتيجة غير متزامنة يُلتقط generation للوثيقة، وتُهمل النتيجة القديمة إذا تغير النص. وعند رفض ghost suggestion يجب أن يمر الحرف الجديد إلى TextField مرة واحدة فقط، لا أن يستخدم الرفض مسار إدخال ثانٍ. يعالج listener حالة hit-testing التي تعيد newline بــ`TextAffinity.upstream` عند النقر في الفراغ، فيثبت caret عند نهاية السطر السابق. ويعترض EditorShell السهمين الأيسر والأيمن دون modifiers ليجعلهما متوافقين مع الحركة البصرية في RTL، مع إبقاء Shift للتحديد.

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
