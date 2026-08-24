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

## مبدأ الدقة

> لا تُسمّى الشفرة التنفيذية artifact إلا إذا وُجد الملف فعلًا، واجتاز البناء والتحقق التشغيلي المقصود، وأُعيد مساره من خلال العقد. ولا تُسمّى Assembly النصية binary assembled ما لم تمر عبر assembler حقيقي.

تستخدم النسخة الحالية target باسم `dart-native` لبناء executable حقيقي عبر `dart compile exe` عند توفر Dart SDK، وتضمّن release SDK المطلوب بجانب compiler. وتبقى صلاحية native backend مرتبطة بالتركيبات التي يغطيها semantic analyzer واختبارات parity؛ لذلك لا تدعي هذه الوثائق دعم كل امتداد مستقبلي قبل إضافة اختبار صريح له.

## مراجع السلوك التحريري

تستفيد مواصفة المحرر من مبادئ VS Code الرسمية في IntelliSense وlanguage configuration وsyntax highlighting، مع تكييفها للغة عربية ومحرر Flutter مستقل.

[1]: https://code.visualstudio.com/docs/editing/intellisense "VS Code IntelliSense"
[2]: https://code.visualstudio.com/api/language-extensions/language-configuration-guide "VS Code Language Configuration Guide"
[3]: https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide "VS Code Syntax Highlight Guide"
[4]: https://code.visualstudio.com/docs/editing/codebasics "VS Code Basic Editing"
