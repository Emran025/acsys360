# دليل مكونات الكود ومسار البيانات

## الغرض

هذا الدليل هو خريطة شرح التقرير، وليس قائمة أسماء ملفات فقط. لكل مكون سبب وجود واضح، ومدخلات ومخرجات وحدود، ومسار ارتباط ببقية المشروع. يشرح الكود الفعلي في المستودع، ولا يستبدل الاختبارات أو يدعي اكتمال وظيفة لم يثبتها التنفيذ.

## المسار العام

```text
المستخدم
  ↓
Flutter EditorShell
  ↓
EditorController ← Workspace / Document / Edit transactions
  ↓
CompilerRepository و AssistRepository
  ↓ JSON protocol 0.5.0
arabicc executable
  ↓
ProjectCompiler → Compiler
  ↓
Lexer → Parser/AST → Semantic → TAC → Typed IR → Assembly → Interpreter
  ↓
CompilationResponse
  ↓
لوحات النتائج والتشخيص وملف artifact عند target مدعوم
```

| المكون | سبب الإضافة | المدخلات | المخرجات | الارتباط والحدود |
|---|---|---|---|---|
| `Document` | جعل النص وdirty state وundo/redo مصدر حقيقة واحدًا لكل ملف | path، text، `TextEdit` | Document جديد immutable | لا يعرف Flutter أو filesystem، ويرفض stale edit لا يطابق النص الحالي |
| `Workspace` | إدارة الجذر والوثائق المفتوحة والتبويب النشط | rootPath، documents، activeIndex | session immutable | يمنع فتح المسار نفسه مرتين ويعيد ضبط activeIndex عند الإغلاق |
| `WorkspaceRepository` | فصل حالات الاستخدام عن نظام الملفات | مسار workspace وعمليات CRUD | Documents وFileNodes | التنفيذ المحلي في `LocalWorkspaceRepository`؛ يمكن استبداله في الاختبارات |
| `WorkspacePathService` | عزل separator وparent/baseName/relocation عن حالة المحرر | مسارات workspace | مسار موحد حسب المنصة أو default قابل للاختبار | adapter المحلي يستخدم `dart:io` في data فقط؛ الـdomain لا يعرف Platform |
| `EditorController` | تجميع حالة المحرر دون جعل Widget مصدرًا ثانيًا للنص | Workspace، commands، repositories | workspace، compilation، diagnostics، assistance | يرسل التعديلات والطلبات، ولا ينفذ parser أو semantic داخل الواجهة |
| `LineNumberedEditor` | عرض مساحة الكود مع gutter وMinimap وTextField | ArabicCodeController، selection، diagnostics | محرر قابل للتحرير والتمرير | ترتيب العرض Minimap ثم code ثم gutter؛ TextField للكود RTL/right حتى يتحرك caret مع العربية، مع بقاء selection offsets مصدر الحركة المنطقية |
| `ArabicCodeController` | تركيب النص الحقيقي مع lexical spans وsemantic refinement وdiagnostic وghost layers | source text، SourceTokens، diagnostics، ghost | `TextSpan` للعرض فقط | لا يغير النص بسبب التلوين أو ghost؛ التلوين ليس language server كاملًا |
| `ArabicSyntaxHighlighter` | إعادة استخدام Lexer الفعلي ومنع ازدواج grammar في الواجهة | source، أدوار رموز اختيارية | `SourceToken` ranges | يحدد التصنيف المعجمي، أما الدور الدلالي الحالي فهو mapping خفيف بالاسم |
| `ToggleLineComment` | تنفيذ command واحد قابل للتراجع وفق grammar | text وbase/extent selection | `LineCommentEdit` مع selection mapping | يدعم `//` فقط؛ لا يضيف block comments غير الموجودة في grammar |
| `FormatArabicSource` | ترتيب indentation دون تغيير literals أو comments | source | source formatted أو النص الأصلي عند عدم اتزان الأقواس | formatter محافظ، وليس إعادة كتابة AST أو pretty-printer كاملًا |
| `ProcessCompilerRepository` | عزل process وstdin/stdout وJSON عن domain وFlutter | documents، mode، target | Map من CompilationResponse أو process diagnostic | يثبت انفصال executable؛ يفرض timeout 30 ثانية ويقتل process العالق ويعيد diagnostic منظمًا بدل نص خام |
| `arabicc.dart` | نقطة الدخول التنفيذية للعقد والمترجم والمساعدة | JSON protocol أو assist request | JSON response حقيقي وexit code | يجمع source snapshots، يمررها إلى ProjectCompiler، ويبني artifact فقط عند target مثبت |
| `ProjectCompiler` | ربط عدة ملفات مع external procedures/types وتشخيصات المشروع | path→source | File results وproject diagnostics وexecution output | يمرر procedure/type declarations الخارجية إلى Interpreter؛ لا يخلط متغيرات الملفات، ولا يضيف module/import grammar مستقلة |
| `Compiler` | تنسيق pipeline الأكاديمي لملف واحد | source وexternal symbols | tokens، AST، symbols، diagnostics، TAC، IR، Assembly، runtime output | كل مرحلة لاحقة مشروطة بصحة المراحل السابقة؛ IR typed مخرج حقيقي من TAC |
| `Lexer` | تحويل source إلى tokens ومواقع وتشخيصات lexical | source | Token list وdiagnostics | مصدر واحد للتلوين والتصنيف؛ التعليقات `//` تُتجاهل في compiler وتُستخرج للعرض |
| `Parser` وAST | تحويل tokens إلى شجرة تركيبية وفق grammar الرسمية | tokens | ProgramNode وsyntax diagnostics | لا يضيف C-like syntax؛ الشجرة serializable للعقد ولوحات النتائج |
| `SemanticAnalyzer` | فحص scopes والأنواع والثوابت والوصول والاستدعاءات | AST وexternal symbols | Symbol table وsemantic diagnostics | يقدم declared spans وreferences الحالية؛ لا يحقق F2/F12 كاملين دون protocol actions |
| `ThreeAddressGenerator` | إخراج تمثيل وسيط قابل للفحص الأكاديمي | AST | قائمة TAC | لا يعمل لمصدر غير صالح وفق pipeline contract |
| `TypedIrProgram` | إضافة نوع IR والتحقق من labels/types فوق TAC | TAC وsymbol types | typed instructions وIR diagnostics | مخرج معروض في protocol 0.5.0؛ ليس native machine code |
| `AssemblyGenerator` | عرض target-like assembly لأغراض المقرر | TAC | Assembly text | يجب تسميته نصًا تعليميًا؛ لا يُعد binary assembled دون assembler حقيقي |
| `Interpreter` | إثبات execution فعلي داخل النطاق المدعوم | AST وinput provider | output وruntime diagnostics | مرجع parity للـdart-native backend في الاختبارات |
| `DartNativeArtifactBuilder` | بناء executable حقيقي للنطاق المثبت | AST وoutput directory وDart executable | artifact path أو diagnostics | target واحد محدود بتركيبات backend؛ لا يمثل compiler native عامًا لكل اللغة |
| `CompilationResponse` | تثبيت seam typed وقابل للتحقق بين executableين | stage payloads وdiagnostics | JSON versioned | protocol `0.5.0` يتحقق من الأنواع والمواقع والقوائم والـIR الاختياري |

## دورة التعديل

يبدأ الحدث من TextField، ثم يحسب `EditorShell` diff واحدًا بين النص السابق واللاحق. يمر `TextEdit` إلى `EditorController.edit` ثم `Document.edit`، حيث يُفحص `offset` و`before` قبل إنشاء Document جديد. بعد ذلك تُبطل diagnostics وassistance القديمة ويُزاد generation، وتُجدول عملية التحليل دون أن تكتب callback قديمة فوق النص الجديد.

النتيجة غير المتزامنة لا تصبح صالحة إلا إذا ظل generation مطابقًا. عند تبديل الملف أو تعديل المصدر تُزال ghost completion القديمة، وعند رفضها ينتقل الحرف إلى TextField مرة واحدة. هذه السلسلة هي سبب فصل `Document` عن `ArabicCodeController`: الأول يملك المصدر، والثاني يملك طبقات العرض المؤقتة.

## دورة الترجمة

عند compile يرسل controller snapshot الوثائق المفتوحة إلى `ProcessCompilerRepository`. يبني adapter طلبًا من `CompilationRequest`، ويختار `active` أو `project`. يستقبل CLI الاستجابة، يتحقق من `CompilationResponse`، ثم يحول diagnostics إلى `EditorDiagnostic` مع إثراء quick fixes المحدودة. لا تنفذ Flutter parser أو semantic؛ فهي تعرض payload الذي عاد من compiler executable.

داخل compiler، يقرأ Lexer source أولًا، ثم يحاول Parser بناء AST. إذا فشل بناء البرنامج تتوقف المراحل التالية. بعد نجاح AST يعمل semantic، ثم TAC وTyped IR، ثم Assembly وInterpreter عند خلو diagnostics. في project mode يجمع ProjectCompiler تعريفات الإجراءات والأنواع الخارجية، ويمررها إلى كل ملف مع أولوية التعريف المحلي، لذلك يمكن تنفيذ procedure أو تهيئة record من ملف آخر. يختار CLI شجرة/IR الملف الواحد مباشرة، بينما يضع نتائج المشروع في كائن project مع قائمة files.

## مخرجات التكليف وحدود الإثبات

| مطلب التكليف | دليل التنفيذ الحالي | حالة الإثبات |
|---|---|---|
| Tokens | `Compiler` و`CompilationResponse.tokens` | مختبر ومُعرض |
| Parse/Syntax Tree | AST `toJson` و`syntaxTree` | مختبر ومُعرض |
| Symbol Table | `SemanticResult` و`symbolTable` | مختبر ومُعرض |
| Syntax/Semantic Errors | diagnostics typed مع phase وspan | مختبر ومُعرض |
| TAC | `ThreeAddressGenerator` و`threeAddressCode` | مختبر ومُعرض |
| Typed IR | `TypedIrProgram` و`intermediateRepresentation` | مختبر ومُعرض |
| Assembly | `AssemblyGenerator` | نص أكاديمي، ليس binary |
| Execution output | `Interpreter` و`executionOutput` | مثبت بأمثلة ناجحة |
| EXE | `dart-native` في backend محدود | مثبت فقط للتركيبات المختبرة |
| عشرة أمثلة مختلفة | `examples/01` إلى `examples/10`، و`examples/errors/11` و`12` | عشرة نجاح + fixture syntax وfixture semantic سلبية |
| محرر مستقل | Flutter executable + `arabicc` process | مثبت في CI/release |
| عزل النتائج غير المتزامنة | `_stateVersion` في `EditorController` | مثبت باختبارات stale compile/completion/save |
| فشل process | timeout وmalformed JSON وexit failure في adapter | مثبت باختبارات protocol وtimeout |

| تنفيذ multi-file | external procedures/types إلى Interpreter وprotocol output | مثبت باختبارات ProjectCompiler وJSON |


## كيف يشرح هذا في التقرير

يُشرح كل مكون في التقرير وفق الترتيب: سبب وجوده، العقد أو المدخلات، الخرج، المتغيرات وهياكل البيانات المهمة، الوظائف الرئيسة، الملف الذي يعتمد عليه، ثم اختبار يثبت السلوك. وتوضع حدود المكون في فقرة مستقلة حتى لا يختلط «يعمل ضمن subset مثبت» مع «يدعم اللغة كاملة».
