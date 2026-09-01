# خطة نقل المترجم إلى C مع الحفاظ على واجهة ACSys360

## القرار المعماري

سيبقى تطبيق Flutter وطبقات العرض والحالة و`ProcessCompilerRepository` كما هي من ناحية الواجهة العامة والسلوك المرئي. التغيير يقع خلف حد العملية فقط: سيُبنى executable مستقل بلغة C يقرأ طلبًا واحدًا من `stdin` ويكتب استجابة JSON واحدة إلى `stdout`. لذلك لا تستدعي الواجهة Lexer أو Parser أو Semantic مباشرة، ولا تحتاج إلى معرفة لغة تنفيذ المترجم.

> معيار القبول الأساسي: يستطيع التطبيق الحالي استبدال executable Dart بـ executable C عبر نفس الوسائط `--protocol` و`--assist`، من دون تعديل وظائف المحرر أو شكل طلبات JSON أو حقول الاستجابة.

## العقد غير القابل للتغيير

| المسار | الإدخال | الإخراج | السلوك المطلوب |
|---|---|---|---|
| `--protocol` | كائن `CompilationRequest` واحد عبر stdin | كائن `CompilationResponse` واحد عبر stdout | `protocolVersion` يظل `0.5.0`، والخروج 0 للنجاح و1 لفشل ترجمة المصدر و64 لخطأ البروتوكول |
| `--assist` | كائن `AssistRequest` واحد عبر stdin | `AssistResponse` واحد عبر stdout | الإكمال والمساعدة يعيدان `requestType=assist` وجميع حقول العقد الحالية |
| legacy source path | مسار ملف واحد | نتيجة JSON مطبوعة | يبقى مسار توافق اختياريًا ولا يُستخدم من Flutter في وضع الإنتاج |

استجابة الترجمة يجب أن تحافظ على الحقول `diagnostics`, `tokens`, `syntaxTree`, `symbolTable`, `threeAddressCode`, `assembly`, `executionOutput`, `artifacts`, و`intermediateRepresentation`. لا يُسمح بحذف حقل أو تحويل قيمة فارغة إلى `null` خلافًا للعقد.

## مطابقة مراحل compiler_core

سيُقسم التنفيذ C إلى وحدات صغيرة ذات ملكية واضحة للذاكرة ومسارات خطأ صريحة:

| مرحلة Dart الحالية | وحدة C المقابلة | الناتج |
|---|---|---|
| `Lexer` | `lexer.c/.h` | tokens مع offset وline وcolumn وdiagnostics |
| `Parser` وAST | `parser.c/.h`, `ast.c/.h` | شجرة البرنامج، declarations، statements، expressions |
| `SemanticAnalyzer` | `semantic.c/.h`, `symbols.c/.h` | symbol table، الأنواع، أخطاء التوافق والنطاق |
| `ProjectCompiler` | `project.c/.h` | جمع الملفات، external procedures/types، فحص التعارضات، entry path |
| `ThreeAddressGenerator` | `tac.c/.h` | TAC مرتب وقابل للمقارنة مع fixtures |
| `TypedIrProgram` | `typed_ir.c/.h` | typed instructions وملخص الأنواع وdiagnostics |
| `AssemblyGenerator` | `asm_x86_64.c/.h` | Assembly x86-64 محدد الهدف مع labels وstack layout |
| `Interpreter` | `runtime.c/.h` | execution output وحد أقصى للخطوات |
| `LanguageAssist` | `assist.c/.h` | completion/help وreplace ranges |
| protocol models | `protocol.c/.h`, `json.c/.h` | parsing وserialization للعقد دون اعتماد Flutter أو Dart |

تُستخدم بنية arena أو قوائم ملكية مركزية لكل compilation request، ويُحرر الطلب كاملًا في نهاية العملية. لا توجد global mutable state بين الطلبات، حتى تكون نتيجة project mode قابلة لإعادة الاختبار.

## قواعد اللغة التي يجب نقلها حرفيًا

الـLexer C يقبل الحروف العربية ضمن النطاقات التي يقبلها التنفيذ الحالي، والأسماء العربية والأرقام والـunderscore. تبقى التعليقات `//` فقط. تبقى punctuation والعمليات الحالية كما هي، ومنها `&&`, `||`, `==`, `!=`, `=<`, `=>`, `<`, `>`, `+`, `-`, `*`, `/`, `%`, `\\`, و`^`.

يجب أن يدعم Parser C العناصر الحالية: `برنامج`، declarations الخاصة بـ`ثابت` و`نوع` و`متغير` و`اجراء`، معاملات `بالقيمة` و`بالمرجع`، الأنواع البدائية والقوائم والسجلات، والإسناد والقراءة والطباعة والاستدعاء و`اذا` و`والا` و`طالما` و`كرر` و`اعد ... حتى`. لا تُضاف صياغة C-like أو block comments أو كلمات جديدة بحجة تسهيل النقل.

## هدف Assembly

الهدف الأول المعلن هو **x86-64 Assembly بصيغة NASM** لنظام Linux ABI، مع فصل أسماء الدوال ونظام الإدخال والإخراج داخل backend. ينتج backend نص Assembly قابلًا للفحص ومحددًا بوضوح، ثم يثبت في CI عبر اختبارات syntax وgolden output. لا يُعلن artifact تنفيذي native إلا بعد إضافة assembler/linker متاحين في CI واختبار تشغيل حقيقي.

لتجنب ادعاء دعم غير مثبت، تظل أهداف Windows وmacOS في المرحلة الأولى مخرجات Assembly نصية لنفس IR، بينما لا يُضاف target ABI آخر إلا مع runtime واختبار مستقل. هذا لا يمنع Flutter من عرض assembly الحالي، ولا يغير عقده.

## project mode والتكافؤ

في `project` mode تُقرأ `sourcePaths`، وتُستخدم `sourceTexts` عند وجودها بدل الملف، وتُحل المسارات بالنسبة إلى `rootPath`. يمر التنفيذ بمرحلة جمع أولى لاستخراج symbols وprocedures وtypes، ثم مرحلة تحليل وترجمة ثانية بالرموز الخارجية. يجب أن تدعم استدعاءات الإجراءات الخارجية وtype aliases الخارجية بنفس نتيجة التنفيذ الحالية.

في `active` mode يقتصر الطلب على `entryPath` وفق السلوك الحالي. أخطاء الملفات تستخدم phase=`io`، وأخطاء JSON تستخدم phase=`protocol`، وأخطاء الترجمة تحمل span كاملًا يحوي المسار والـoffset والسطر والعمود والطول.

## بوابات التنفيذ

لا يُستبدل executable الحالي مباشرة. تُبنى النسخة C أولًا باسم مستقل، وتُشغّل على fixtures نفسها، ثم تُقارن الاستجابات دلاليًا مع المرجع Dart بعد تجاهل الحقول التي يسمح العقد باختلاف ترتيبها. لا يحدث الدمج خلف `ProcessCompilerRepository` إلا بعد تحقق البوابات الآتية:

| البوابة | معيار القبول |
|---|---|
| C build | `-std=c17 -Wall -Wextra -Werror` على Linux، وبناء Windows/macOS في CI |
| protocol | malformed JSON، protocol mismatch، empty sources، وجميع الحقول الإلزامية |
| lexer/parser | fixtures النجاح والأخطاء مع spans ثابتة |
| semantic/project | external procedures/types، duplicate symbols، type errors |
| runtime | execution output نفسه وحد الخطوات نفسه |
| TAC/Typed IR | golden tests وأسماء temporaries وترتيب التعليمات |
| Assembly | golden NASM output، labels، precedence، ورفض source غير صالح |
| integration | تشغيل Flutter الحالي ضد executable C دون تغيير widget أو state APIs |

## استراتيجية الدمج

يُضاف مجلد `packages/compiler_c` بجانب `packages/compiler_core`، ولا يُحذف Dart compiler خلال فترة التكافؤ. بعد نجاح كل البوابات يُغيّر release workflow فقط ليبني executable C ويضعه في المسار نفسه `compiler/arabicc[.exe]`. تبقى واجهة Flutter كما هي، وتظل نسخة Dart متاحة كمرجع اختبارات وfallback تطويري إلى أن يوافق التكليف على إزالة المرجع.

أي فرق بين نتائج C وDart يجب أن يسجل كاختبار أو قرار موثق، لا أن يُخفى بتحويل الاستجابة أو إسقاط المرحلة. الهدف هو compiler C حقيقي ذو pipeline واضح وAssembly قابل للتحقق، وليس wrapper يستدعي compiler Dart أو مولد نص Assembly شكلي.
