# تقرير التدقيق العميق والتصحيح

> هذا تقرير تاريخي عن جولة تدقيق سابقة، وليس جردًا كاملًا للبنية الحالية. المرجع التشغيلي الحالي هو [وثيقة المعمارية](../architecture/architecture.md) و[استراتيجية الاختبار](../testing/test-strategy.md).

## الغرض

يوثق هذا الملف دورة التدقيق التي سبقت الدمج التالي، لا مجرد قائمة بالميزات. كان معيار القبول هو أن يكون لكل وظيفة مصدر حقيقة واحد، وعقد واضح، وسيناريو فشل مفهوم، واختبار يثبت السلوك، ووثيقة تشرح الحد الذي لا يجوز تجاوزه في الادعاء.

## منهج الحلقة

تكررت الحلقة على خمس خطوات: جرد المتطلب ومكان تنفيذه، تتبع مسار البيانات من الإدخال إلى المخرج، اختيار حالة حدية أو سباق محتمل، كتابة regression test قبل اعتبار التصحيح صحيحًا، ثم إعادة format/analyze/test ومراجعة diff. إذا ظهر فشل في أي خطوة عادت الحلقة إلى التشخيص بدل تسجيل نجاح شكلي.

| الجولة | نقطة الفحص | النتيجة | الإجراء |
|---|---|---|---|
| 1 | baseline وREADME وSkill وقواعد اللغة | التنفيذ السابق كان يعمل، لكن بعض الوثائق لا تشرح السبب والحدود | بناء مصفوفة مطابقة ودليل مكونات |
| 2 | EditorController وDocument وWorkspace | نتائج compile/assist/save القديمة يمكن أن تصل بعد edit أحدث | إضافة `_stateVersion` واختبارات deferred operations |
| 3 | Flutter RTL والاختصارات واللوحة | binding التعليق والتكبير يحتاج إثباتًا مرئيًا، وexecution output كان يستخدم escape نصيًا | إضافة widget regressions وإصلاح newline الفعلية |
| 4 | Clean Architecture والمسارات | `EditorController` يعرف `Platform.pathSeparator` مباشرة | استخراج `WorkspacePathService` وadapter محلي في data |
| 5 | multi-file runtime | procedure/type resolution لا يكفي إذا تعطّل execution الخارجي | تمرير procedure/type declarations إلى Interpreter وإثبات output عبر JSON |
| 6 | Typed IR | constructor داخلي كان يخلط operator وright operand، و`<=`/`>=` لا تُصنف boolean | إصلاح constructor، inference، واختبارات operands/types |
| 7 | process seam وCI | process العالق قد يجمد المحرر، وformat gate لا يشمل الحزم | timeout مع kill، وتوسيع format gate في CI وrelease |

## قرارات المكونات

### مصدر النص والحالة

`Document` هو مصدر النص immutable، ويقبل `TextEdit` فقط عندما يطابق `before` النص الحالي ويقع `offset` داخل الحدود. هذا يمنع callback قديمة أو quick fix stale من إعادة تركيب النص بصمت. `Workspace` يملك قائمة الوثائق والتبويب النشط، بينما `EditorController` ينسق commands والنتائج ولا يملك parser أو semantic.

### التلوين والتفاعل

يستخدم `ArabicSyntaxHighlighter` الرموز التي ينتجها lexer الحقيقي في `packages/compiler_c` لمنع تكرار قائمة الكلمات والعمليات في Flutter. يحوّل tokens إلى `SourceToken` ranges؛ ثم يضيف `ArabicCodeController` طبقة الأدوار الدلالية والتشخيص وghost للعرض فقط. التعليقات المعتمدة هي `//`، ولذلك لا يستخرج highlighter أو ToggleLineComment block comments غير موجودة في grammar.

كانت المحاولة السابقة تستخدم `TextDirection.ltr` مع `TextAlign.right` لعزل حركة المؤشر عن محاذاة السطر، لكنها أثبتت في اختبار caret أن موضع النهاية قد يعود إلى الحافة اليمنى عند النص العربي المختلط. التصحيح النهائي يستخدم `TextDirection.rtl` مع `TextAlign.right`؛ فتتحرك مواضع caret مع الإدخال العربي. ويطبّع `LineNumberedEditor` حالة hit-testing التي تعيد newline بــ`TextAffinity.upstream` عند النقر في الفراغ إلى نهاية السطر السابق. كما يعكس EditorShell السهمين الأيسر والأيمن بصريًا في RTL، مع إبقاء selection offsets وShift للتحديد. أصبح ترتيب العرض صريحًا: Minimap يسار مساحة الكود، وgutter أرقام الأسطر يمينها. التكبير عام عبر `MediaQuery.textScaler` مرة واحدة، ولا تضاعف LineNumberedEditor أو gutter حجم الخط فوقه.

### التعليقات والتنسيق

`ToggleLineComment` use case واحد يعالج السطر الحالي أو الأسطر المحددة، ويضع marker بعد indentation مع `// `، ولا يفك التعليق إلا إذا كانت كل الأسطر غير الفارغة قابلة للفك. يعيد selection mapping ويحافظ على اتجاه التحديد ويُرسل من EditorShell كتعديل واحد، لذلك يدخل undo/redo بصورة طبيعية.

`formatArabicSource` formatter محافظ: يزيل trailing spaces ويحسب indentation من الأقواس خارج string وcharacter و`// comment`. عند literal غير مغلق أو blocks غير متوازنة يعيد المصدر كما هو بدل إتلاف ملف المستخدم. لا يدعي أنه AST pretty-printer كاملًا.

## تصحيحات compiler الأساسية

في project mode يجمع `ProjectCompiler` تعريفات الإجراءات والأنواع فقط كرموز خارجية، مع بقاء متغيرات الملفات غير متسربة إلى بعضها. يمرر الإجراءات والأنواع الخارجية إلى `Compiler` ثم `Interpreter`، وتُعطى التعريفات المحلية أولوية التنفيذ. أثبت اختبار ProjectCompiler واختبار protocol أن استدعاء procedure من ملف آخر يعيد output `3`، وأن record type الخارجي يمكن تهيئته والوصول إلى حقله. لا توجد grammar import أو module مستقلة؛ هذا الحد متعمد وموثق.

في Typed IR أصبح `typeOf` يتتبع temporaries، ويستنتج أنواع unary والعمليات الحسابية والمقارنات، ويعامل كلًا من صيغ TAC الداخلية `<=` و`>=` والصيغ العربية `=<` و`=>` كمقارنات boolean. أُضيفت assertions على operand/operator/result type لأن فحص `isValid` وحده لا يكشف تبديل الحقول.

في process adapter أصبح بدء compiler وجمع stdout/stderr/exitCode محميًا بحد انتظار 30 ثانية. عند انتهاء الحد يُعاد diagnostic process منظم، ويُقتل process إذا كان عالقًا بعد البدء. هذا يحمي واجهة Flutter من انتظار غير محدود، ولا يخفي فشل executable على أنه CompilationResponse ناجحة.

## مصفوفة الأدلة

| السلوك | الاختبار أو الدليل | الحالة |
|---|---|---|
| stale compile/completion/save | `test/editor_controller_async_test.dart` | مثبت |
| source path diagnostics | `test/editor_language_server_test.dart` | مثبت |
| POSIX وWindows-style path policy | `test/workspace_path_service_test.dart` | مثبت |
| comment mapping والاتجاه والفراغ | `test/toggle_line_comment_test.dart` | مثبت |
| formatter وCRLF وliteral غير مغلق | `test/format_arabic_source_test.dart` | مثبت |
| RTL وEnter عند offset صفر وghost | `test/widget_test.dart` | مثبت |
| Ctrl/Cmd+/ وzoom/reset وexecution output | `test/widget_test.dart` | مثبت |
| compiler protocol وexecution output | `packages/compiler_contracts/test/compilation_protocol_test.dart` و`tool/verify_compiler_bundle.dart` | مثبت |
| C backend build وsmoke | `packages/compiler_c/CMakeLists.txt` و`tool/verify_compiler_bundle.dart` | مثبت |
| process timeout | `test/process_compiler_repository_test.dart` | مثبت |
| syntax/semantic negative fixtures | `examples/errors/` واختبارات compiler المسجلة في `packages/compiler_c/CMakeLists.txt` | مثبت ضمن اختبارات compiler الحالية |

## نتيجة الجولة المحلية

قبل إصدار `v0.0.1` نجح format gate الموسع، و`flutter analyze`، و`flutter test`، وبناء C backend على Linux وWindows وmacOS. كما نجحت اختبارات smoke للمترجم المضمن في تشغيل Release [`34700784289`](https://github.com/Emran025/acsys360/actions/runs/34700784289) على commit `e6e8785`، وشملت jobs المنصات الثلاث ومرحلة publish.

## حدود لم تُخفَ

لا تزال F2 وF12 وCtrl/Cmd+. المباشر تحتاج protocol actions ومواقع رموز AST دقيقة. الأدوار الدلالية الحالية mapping بالاسم، ولذلك لا تحل shadowing الكامل. Assembly المخرجة نص تعليمي NASM-like وليست binary assembled، وC backend محدود بالـsubset الذي يمر عبر parser والتحليل واختبارات smoke. كما أن project runtime لا يقدم import/module grammar ولا يخلط global variables بين الملفات.

## قرار الدمج

اجتاز commit `e6e8785` workflow الإصدار الذي يشمل format، analyze، اختبارات Flutter، بناء C backend، bundling واختبارات smoke للمنصات الثلاث في التشغيل `34700784289`. لذلك أُنشئ Release `v0.0.1` من هذا commit. تُذكر أرقام التشغيل والcommit والأصول دون تقريب أو استنتاج من نتيجة محلية.
