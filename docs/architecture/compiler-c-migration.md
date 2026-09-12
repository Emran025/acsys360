# سجل نقل المترجم إلى C مع الحفاظ على واجهة ACSys360

> هذه الوثيقة تصف قرار الانتقال بعد تنفيذه. المسارات القديمة مثل `packages/compiler_core` ونسخة Dart من `arabicc` كانت جزءًا من الخطة السابقة وليست بنية التشغيل الحالية.

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

## وحدات التنفيذ الحالية

سيُقسم التنفيذ C إلى وحدات صغيرة ذات ملكية واضحة للذاكرة ومسارات خطأ صريحة:

| مرحلة المترجم الحالية | وحدة C المقابلة | الناتج |
|---|---|---|
| `Lexer` | `src/lexer.l` عبر Flex | tokens مع offset وline وcolumn وdiagnostics |
| `Parser` وAST | `src/parser.y`, `src/ast.c`, `include/ast.h` | شجرة البرنامج، declarations، statements، expressions |
| `SemanticAnalyzer` | `src/semantic.c`, `include/semantic.h` | symbol table والأنواع وأخطاء التوافق والنطاق |
| `ProjectCompiler` | `src/protocol.c` و`src/main.c` | قراءة الطلب، source paths، entry path، وتجميع الاستجابة |
| `ThreeAddressGenerator` | `src/protocol.c` | TAC النصي ضمن response |
| `TypedIrProgram` | `src/protocol.c` | intermediate representation ضمن response |
| `AssemblyGenerator` | `asm_x86_64.c/.h` | Assembly x86-64 محدد الهدف مع labels وstack layout |
| `Interpreter` | `runtime.c/.h` | execution output وحد أقصى للخطوات |
| `LanguageAssist` | `src/protocol.c` و`src/main.c` | completion/help وreplace ranges |
| protocol models | `src/protocol.c`, `include/protocol.h` | parsing وserialization للعقد دون اعتماد Flutter أو Dart |

تُدار ذاكرة الطلب داخل وحدات C الحالية وتُحرر الاستجابة في نهاية المعالجة. يجب اعتبار حدود دعم project mode والذاكرة جزءًا من اختبارات backend، لا افتراضات من خطة النقل القديمة.

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

## استراتيجية الدمج المنفذة

يوجد `packages/compiler_c` الآن بوصفه backend المضمن في التطبيق. يبني `release.yml` executable `arabicc` لكل منصة ويضعه في `compiler/arabicc[.exe]` داخل Desktop bundle. تبقى واجهة Flutter وعقد JSON كما هي، بينما تنفذ data layer عملية التشغيل وتحوّل الاستجابة عبر `packages/compiler_contracts`.

أي فرق بين نتائج C وDart يجب أن يسجل كاختبار أو قرار موثق، لا أن يُخفى بتحويل الاستجابة أو إسقاط المرحلة. الهدف هو compiler C حقيقي ذو pipeline واضح وAssembly قابل للتحقق، وليس wrapper يستدعي compiler Dart أو مولد نص Assembly شكلي.
