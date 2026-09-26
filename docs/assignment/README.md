# وثائق تكليف مترجم اللغة العربية ومحرره

## الغرض

تجمع هذه الحزمة وثائق التكليف في ملفات Markdown مستقلة قابلة للتحويل لاحقًا إلى Word. تصف الوثائق اللغة العربية المحددة في ملف القواعد، وبنية المترجم، ومحرر سطح المكتب، والعقد بين البرنامجين، وخطة الاختبارات والبناء والتسليم.

## خريطة الوثائق

| الملف | المحتوى |
|---|---|
| [01-requirements.md](01-requirements.md) | متطلبات التكليف، المخرجات الأكاديمية، وحدود النطاق |
| [02-architecture.md](02-architecture.md) | Clean Architecture وفصل المحرر عن compiler executable |
| [03-language-and-compiler.md](03-language-and-compiler.md) | القواعد الرسمية ومراحل Lexer إلى artifact |
| [04-editor-behavior.md](04-editor-behavior.md) | مواصفة تفاعل المحرر وسلوك الاقتراح والمؤشر والتنسيق |
| [05-testing-and-build.md](05-testing-and-build.md) | الاختبارات، CI، الإصدارات، ومعايير القبول |
| [06-deliverables-checklist.md](06-deliverables-checklist.md) | قائمة التسليم النهائية ومطابقة الملفات للمطلوب |
| [07-vscode-editing-reference.md](07-vscode-editing-reference.md) | خلاصة دراسة سلوك VS Code ومراجعها التنفيذية |
| [08-minimap-reference.md](08-minimap-reference.md) | مواصفة Minimap والتنقل السريع داخل الملف |
| [09-quality-gates.md](09-quality-gates.md) | بوابة الجودة الإنتاجية والأكاديمية ومعايير القبول |
| [10-vscode-highlighting-findings.md](10-vscode-highlighting-findings.md) | نتائج دراسة VS Code وتطبيقها على التلوين والتعليقات والإزاحة |
| [11-editor-command-and-language-status.md](11-editor-command-and-language-status.md) | حالة أوامر المحرر وخدمة اللغة وقواعد RTL وبوابة الإثبات |
| [12-code-component-guide.md](12-code-component-guide.md) | سبب وجود المكونات ومسار البيانات والمدخلات والمخرجات والحدود |
| [13-deep-audit-report.md](13-deep-audit-report.md) | تقرير تدقيق تاريخي؛ ليس جرد البنية الحالية |
| [../architecture/dependencies.md](../architecture/dependencies.md) | الأدوات والإصدارات والغرض ومواضع الاستخدام |
| [../architecture/project-code-map.md](../architecture/project-code-map.md) | شجرة تنفيذية موسعة ومسؤوليات الملفات والدوال والمكتبات وأدوات البناء |

## مبدأ الدقة

> لا تُسمّى الشفرة التنفيذية artifact إلا إذا وُجد الملف فعلًا، واجتاز البناء والتحقق التشغيلي المقصود، وأُعيد مساره من خلال العقد. ولا تُسمّى Assembly النصية binary assembled ما لم تمر عبر assembler حقيقي.

تستخدم النسخة الحالية backend C في `packages/compiler_c` لبناء executable حقيقي باسم `arabicc` عبر CMake وFlex وBison. ويُضمّن executable بجانب تطبيق Desktop في حزم الإصدار وفق workflow المنصة. وتبقى صلاحية backend مرتبطة بالتركيبات التي يغطيها parser والتحليل الدلالي والاختبارات؛ لذلك لا تدعي هذه الوثائق دعم كل امتداد قبل إضافة اختبار صريح له. توجد أمثلة يستهلكها compiler في `examples/manual/` و`examples/`، وملفات أخطاء في `examples/errors/`.

لشرح كيفية عمل كل جزء من المشروع، ومسار البيانات من الواجهة إلى compiler، راجع [خريطة الشيفرة](../architecture/project-code-map.md). وللحالة التنفيذية الحالية والاختبارات التي لا تزال بحاجة إلى تغطية، راجع [حدود المنتج](../architecture/product-boundary.md) و[استراتيجية الاختبار](../testing/test-strategy.md). أما [تقرير التدقيق](13-deep-audit-report.md) و[قائمة التأسيس](../roadmap/foundation-issues.md) فهما سجلان تاريخيان وليسا جردًا حاليًا.

## مراجع السلوك التحريري

تستفيد مواصفة المحرر من مبادئ VS Code الرسمية في IntelliSense وlanguage configuration وsyntax highlighting، مع تكييفها للغة عربية ومحرر Flutter مستقل. ويستخدم التلوين الحالي tokens الناتجة من lexer الفعلي في `packages/compiler_c/src/lexer.l` للطبقة المعجمية، مع refinement دلالي خفيف بالأدوار المستخرجة من compilation result؛ ولا يُعد ذلك language server كاملًا أو تحديد مواقع رموز دقيقة.

[1]: https://code.visualstudio.com/docs/editing/intellisense "VS Code IntelliSense"
[2]: https://code.visualstudio.com/api/language-extensions/language-configuration-guide "VS Code Language Configuration Guide"
[3]: https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide "VS Code Syntax Highlight Guide"
[4]: https://code.visualstudio.com/docs/editing/codebasics "VS Code Basic Editing"
