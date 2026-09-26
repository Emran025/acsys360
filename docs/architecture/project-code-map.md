# خريطة الشيفرة ومسؤولية كل جزء

هذه الخريطة تشرح ملفات المصدر الرئيسية ومسار عملها من تشغيل التطبيق إلى حفظ الملف أو ترجمة البرنامج. شجرة الملفات أدناه مقصودة لتكون خريطة تنفيذية؛ لا تعرض ملفات البناء المتولدة أو كامل platform boilerplate. عند التغيير، يُرجع إلى الملف والاختبار المقابلين بدل اعتبار أسماء المجلدات وحدها وصفًا كافيًا.

## 1. صورة النظام من البداية إلى النتيجة

```text
تشغيل التطبيق
  └─ lib/main.dart: main()
       ├─ config/di/injection.dart: ServiceLocator
       │    ├─ LocalWorkspaceRepository
       │    ├─ createCompilerRepository()
       │    ├─ LocalWorkspacePathService
       │    ├─ NativeArtifactRunner
       │    └─ FilePickerDocumentService
       └─ ArabicEditorApp → AppRouter → EditorShell
            ├─ إدخال المستخدم
            │    └─ TextField / مفاتيح / WorkspaceExplorer
            │         └─ EditorController
            │              ├─ use cases + entities
            │              └─ WorkspaceRepository / DocumentFileService
            │                    └─ ملفات النظام / file_picker
            └─ Compile / Assist / Build
                 └─ ProcessCompilerRepository
                      ├─ JSON request (protocol 0.5.0)
                      ├─ تشغيل arabicc كعملية مستقلة
                      └─ JSON stdout + stderr + exit code
                           └─ compiler_contracts
                                └─ CompilationResult / Diagnostics / Tokens
                                     ├─ editor state + ArabicCodeController
                                     └─ diagnostics وstage panels

داخل عملية arabicc:
stdin line
  → main.c → c_run_protocol() → compiler_driver_run()
      ├─ decode request وقراءة snapshots/خيارات التشغيل
      ├─ Flex lexer → tokens
      ├─ Bison parser → AST
      ├─ semantic analysis → symbols/diagnostics
      ├─ TAC → Typed IR
      ├─ Interpreter عند طلب execution
      ├─ x86-64 NASM generation
      ├─ artifact builder + toolchain عند target تنفيذي
      └─ JSON response → stdout line
```

الاتصال بين Dart وC هو **عملية نظام وJSON عبر stdin/stdout**، وليس استدعاء مكتبة C عبر FFI. `compiler_contracts` يتحقق من شكل الرسائل في Dart؛ أما executable C فيحلل JSON ويكوّن الاستجابة من جهته.

## 2. شجرة المصدر المفصلة

```text
acsys360/
├── assets/
│   ├── branding/arabic360.png
│   └── fonts/Cairo.ttf
├── lib/
│   ├── main.dart
│   ├── config/di/injection.dart
│   ├── routes/app_router.dart
│   ├── core/
│   │   ├── constants/{app_colors,app_constants}.dart
│   │   ├── error/{exceptions,failures}.dart
│   │   ├── services/workspace_path_service.dart
│   │   ├── usecases/usecase.dart
│   │   └── utils/app_strings.dart
│   ├── shared/
│   │   ├── themes/app_theme.dart
│   │   └── widgets/collapsible_panel.dart
│   └── features/editor/
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── compiler_process_factory.dart
│       │   │   ├── file_picker_document_service.dart
│       │   │   ├── local_workspace_path_service.dart
│       │   │   └── native_artifact_runner.dart
│       │   └── repositories_impl/
│       │       ├── local_workspace_repository_impl.dart
│       │       └── process_compiler_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── compilation_result.dart
│       │   │   ├── document.dart
│       │   │   ├── editor_diagnostic.dart
│       │   │   ├── file_node.dart
│       │   │   ├── source_token.dart
│       │   │   └── workspace.dart
│       │   ├── repositories/{program_runner,workspace_repository}.dart
│       │   ├── services/
│       │   │   ├── document_file_service.dart
│       │   │   └── source_file_policy.dart
│       │   └── usecases/
│       │       ├── arabic_language_service.dart
│       │       ├── arabic_syntax_highlighter.dart
│       │       ├── editor_language_server.dart
│       │       ├── find_replace.dart
│       │       ├── format_arabic_source.dart
│       │       ├── toggle_line_comment.dart
│       │       └── workspace_actions.dart
│       └── presentation/
│           ├── controllers/editor_controller.dart
│           └── ui/
│               ├── screens/editor_screen.dart
│               └── widgets/
│                   ├── arabic_code_controller.dart
│                   ├── arabic_file_icon.dart
│                   ├── code_minimap.dart
│                   ├── collapsible_panel.dart
│                   ├── diagnostic_lamp_dialog.dart
│                   ├── diagnostic_popover_widget.dart
│                   ├── diagnostics_panel_widget.dart
│                   ├── editor_breadcrumbs_widget.dart
│                   ├── editor_dialogs.dart
│                   ├── editor_intents.dart
│                   ├── editor_tabs_widget.dart
│                   ├── editor_top_bar.dart
│                   ├── find_replace_bar.dart
│                   ├── help_popover_widget.dart
│                   ├── line_numbered_editor.dart
│                   ├── no_folder_explorer_widget.dart
│                   ├── status_bar_widget.dart
│                   ├── welcome_editor_widget.dart
│                   └── workspace_explorer.dart
├── packages/
│   ├── compiler_contracts/
│   │   ├── lib/compiler_contracts.dart
│   │   ├── lib/src/compilation_protocol.dart
│   │   └── test/{compilation_protocol,assist_protocol}_test.dart
│   └── compiler_c/
│       ├── CMakeLists.txt
│       ├── build.bat / build.ps1
│       ├── include/                       # عقود وهياكل ووظائف وحدات C
│       ├── src/
│       │   ├── main.c
│       │   ├── protocol.c
│       │   ├── protocol/{protocol_json,protocol_request,protocol_response}.c
│       │   ├── driver/compiler_driver.c
│       │   ├── lexer.l / parser.y / ast.c / semantic.c
│       │   ├── ir/{tac,typed_ir}.c
│       │   ├── runtime/interpreter.c
│       │   └── backend/
│       │       ├── {artifact_builder,toolchain}.c
│       │       └── x86_64/asm_x86_64*.c
│       └── tests/                         # C golden/security + Dart integration
├── test/                                  # اختبارات التطبيق
├── examples/{manual,errors}/              # برامج وfixtures
├── tool/                                  # build, diagnostics, bundle verification
├── docs/{architecture,assignment,roadmap,testing}/
└── .github/workflows/{ci,release,container}.yml
```

## 3. تطبيق Flutter: من الواجهة إلى البيانات

| الجزء | ملفات/أنواع محورية | المسؤولية العملية |
|---|---|---|
| نقطة التشغيل | `main()` و`ArabicEditorApp` في `lib/main.dart` | ينشئ controller وخدمة الملفات، يهيئ `MaterialApp` والثيمين، ويوصل التوجيه إلى التطبيق |
| تركيب الاعتماديات | `ServiceLocator.createEditorController()` و`createDocumentFileService()` | يركب local repository، compiler/assistant process adapter، path service، artifact runner وfile picker |
| التوجيه | `AppRoutes` و`AppRouter.onGenerateRoute()` | يوجه `/` و`/editor` إلى `EditorShell` مع تمرير الاعتماديات؛ لا ينشئ مستودعات بنفسه |
| مصدر الحالة | `EditorController` في `presentation/controllers/` | يملك حالة workspace، الملف النشط، الملفات والشجرة، نتائج compile/assist، التشخيصات والبحث. ينسق use cases والمستودعات ولا يحتوي تنفيذ grammar |
| نموذج الوثيقة | `Document` في `domain/entities/document.dart` | يحتفظ بالنص المحفوظ والحالي وdirty state وعمليات undo/redo. `edit` ينتج حالة جديدة مع التحقق من موضع/نص سابق مناسب |
| نموذج workspace | `Workspace` في `domain/entities/workspace.dart` | يحفظ root path ومجموعة الوثائق المفتوحة والتبويب النشط وعمليات التحديث/الإغلاق |
| Explorer | `WorkspaceExplorer` و`NoFolderExplorerWidget` | يعرض شجرة workspace أو المحررات المفتوحة قبل اختيار مجلد. ينفذ العرض عبر callbacks؛ القراءة والإنشاء والنقل والحذف مسؤولية controller/repository |
| أسماء الشجرة | `Text` في `workspace_explorer.dart` | أسماء الجذر والملف والمجلد تستخدم LTR ومحاذاة يمين حتى يبقى ترتيب الاسم/الامتداد طبيعيًا داخل الواجهة RTL |
| محرر النص | `EditorShell` و`LineNumberedEditor` و`ArabicCodeController` | يربط TextField بالمستند، يحسب تحريرًا واحدًا لكل تغير، ويحافظ على selection/scroll؛ يعرض gutter وMinimap والتشخيصات |
| أوامر لوحة المفاتيح | `editor_intents.dart` وbindings في `editor_screen.dart` | يحول مفاتيح الحفظ/التحرير/compile/zoom إلى Intents ثم CallbackActions؛ معالجة Tab/Enter والأسهم وcompletion في key handler |
| عرض compiler | `diagnostics_panel_widget.dart` وبقية stage widgets داخل `editor_screen.dart` | تعرض tokens وAST وsymbols وTAC وIR وAssembly وexecution output والـartifacts دون إعادة ترجمة المصدر |
| الخدمات المشتركة | `AppTheme`, `AppColors`, `AppStrings` وcollapsible panel | توحيد ثيم light/dark، ألوان/ثوابت ونصوص، وسلوك طي اللوحات |

### واجهة المتحكم وحقول حالة الواجهة

`EditorController` هو واجهة الأوامر العامة التي تستدعيها الواجهة. هذه الأسماء مفيدة لتتبع المهمة من الزر إلى النتيجة:

| مجموعة الأوامر | الدوال العامة على `EditorController` |
|---|---|
| workspace والملفات | `changeRoot`, `refreshFiles`, `create`, `createFolder`, `open`, `save`, `saveAs`, `delete`, `cut`, `selectExplorerPath`, `paste`, `rename`, `saveAll` |
| التبويبات والتحرير | `selectTab`, `closeTab`, `edit`, `formatActive`, `undo`, `redo`; والـgetter `activeDocument` |
| البحث والاستبدال | `search`, `firstMatch`, `previousMatch`, `nextMatch`, `replaceCurrent`, `replaceAll`; والـgetter `currentMatch` |
| اللغة والبناء والتنفيذ | `analyze`, `compile`, `buildNative`, `runNative`, `complete`, `help`, `applyCodeAction`, `clearAssist`, `reportError`; والـgetters `languageServer`, `currentCompletion` |
| الإكمال | `nextCompletion`, `previousCompletion`; والحالة `assistanceIndex` |

أهم حالة يملكها المتحكم: `workspace`, `files`, `tree`, `activeDocument`, `compilation`, `diagnostics`, `assistance`, `searchMatches`, `currentMatchIndex`, `error`, `cutPath`, `selectedExplorerPath`، و`selectedDirectoryPath`. يستخدم إصدارات داخلية للـworkspace وطلبات compile حتى لا تستبدل نتيجة غير متزامنة قديمة حالة أحدث.

`EditorShell` في `editor_screen.dart` يربط هذه الأوامر بتفاصيل التفاعل المحلي للشاشة. تشمل نقاطه الأساسية `_syncDocument` لمزامنة النص والتشخيصات والأدوار الدلالية، و`_scheduleAnalysis` للتحليل/الإكمال المؤجل، و`_compileActive` للبناء والتنفيذ، و`_handleEditorKey` و`_acceptCompletion` لحركة لوحة المفاتيح وقبول الاقتراح، ودوال `_search`/`_replace...` للبحث، و`_newFileAt`/`_deletePath`/`_renamePath` لعمليات Explorer. هذه دوال حالة Widget خاصة وليست بديلًا عن أوامر المتحكم.

وتفصل Widgets مسؤولية العرض/الإدخال:

| العنصر | الدور |
|---|---|
| `WorkspaceExplorer` | يعرض الشجرة ويرسل الاختيار وطلبات الملف/المجلد عبر callbacks؛ لا ينفذ filesystem بنفسه |
| `LineNumberedEditor` | يركب منطقة النص وأرقام الأسطر وMinimap |
| `ArabicCodeController` | يحتفظ بمدخلات الرسم: `diagnostics`, `semanticRoles`, `ghostText`, `ghostOffset`؛ و`buildTextSpan` يبني النص الملون والتسطير والاقتراح الشبح |
| `EditorTabsWidget` و`EditorBreadcrumbsWidget` | عرض التبويبات ومسار الملف الحالي |
| `DiagnosticsPanelWidget`, `DiagnosticPopoverWidget`, `HelpPopoverWidget` | عرض التشخيصات وإجراءاتها والمساعدة |
| `FindReplaceBar`, `StatusBarWidget`, `EditorTopBar` | واجهة البحث/الاستبدال وحالة المحرر وأوامر الشريط العلوي |

### حالات الاستخدام والمنطق القابل لإعادة الاستخدام

| ملف/رمز | وظيفته |
|---|---|
| `ArabicSyntaxHighlighter.tokenize(source, {roles})` — `arabic_syntax_highlighter.dart` | يصنف المصدر إلى ranges معجمية/دلالية لعرضه؛ لا يغير النص ولا يحل محل parser المترجم |
| `EditorLanguageServer.analyze`, `.complete`, `.help` — `editor_language_server.dart` | يستدعي compiler/assistant؛ يحذف execution output عند التحليل غير التنفيذي، يختار تشخيصات الملف الحالي ويثريها عبر `ArabicLanguageService`؛ الاسم لا يعني تطبيق بروتوكول LSP كامل |
| `ArabicLanguageService.enrichDiagnostics` — `arabic_language_service.dart` | يحول تشخيصات compiler ويضيف إجراءات إصلاح محدودة للتشخيصات المعروفة |
| `formatArabicSource(source)` — `format_arabic_source.dart` | تنسيق محافظ للمسافات البادئة اعتمادًا على الأقواس؛ لا يعيد بناء AST |
| `ToggleLineComment.apply(text, selectionBase, selectionExtent)` — `toggle_line_comment.dart` | يبني تعديل تعليق/فك تعليق للأسطر باستخدام `//` ويعيد مواضع التحديد بعد التعديل |
| `FindText.call` و`ReplaceAllText.call` — `find_replace.dart` | حساب التطابقات واستبدالها جميعًا؛ استبدال التطابق الحالي وتحديده تديره واجهة المحرر |
| `OpenDocument.call`, `SaveDocument.call`, `ApplyEdit.call`, `UndoEdit.call`, `RedoEdit.call` — `workspace_actions.dart` | حالات استخدام لفتح/حفظ الوثيقة وتطبيق التعديل والتراجع والإعادة فوق كيانات workspace وعقد المستودع |
| `SourceFilePolicy` و`DocumentFileService` | يحددان سياسة امتداد المصدر ويعزلان اختيار/حفظ الملف الخارجي عن واجهة الشاشة |

### مستودعات ومصادر البيانات

| الملف | كيف يعمل |
|---|---|
| `LocalWorkspaceRepository` — `local_workspace_repository_impl.dart` | يطبق `WorkspaceRepository`: فتح/قراءة/حفظ، سرد الملفات والشجرة، إنشاء ملف/مجلد، حذف، نقل وإعادة تسمية، مع قواعد حدود workspace |
| `ProcessCompilerRepository` — `process_compiler_repository_impl.dart` | يحول طلبات المجال إلى request protocol، يبدأ executable، يرسل JSON، يجمع stdout/stderr/exit code، يتحقق من الاستجابة والمهلة، ويعرض مسارات compile وassist والإدخال |
| `createCompilerRepository` — `compiler_process_factory.dart` | يبحث أولًا عن بناء compiler في شجرة المصدر حتى لا يحجب executable قديم النسخة الحديثة، ثم عن النسخة المضمّنة، وأخيرًا يستخدم اسم executable من `PATH`؛ ويضيف مجلد toolchain المضمّن إلى بيئة العملية |
| `LocalWorkspacePathService` | adapter لمنطق المسارات حسب النظام التشغيلي؛ يعزل `dart:io`/platform separator عن domain |
| `FilePickerDocumentService` | يستعمل `file_picker` لاختيار ملف أو مجلد وحفظ/تصدير مستند من واجهة Flutter |
| `NativeArtifactRunner` | يشغل الملف التنفيذي الذي أعاده compiler عبر عقد `ProgramRunner`؛ لا يبني assembly بنفسه |

## 4. حزمة `compiler_contracts`

`packages/compiler_contracts` حزمة Dart صغيرة مشتركة بين التطبيق والاختبارات. تصدّر `compiler_contracts.dart` نماذج protocol المعرفة في `compilation_protocol.dart`. تضم النماذج:

- `CompilationRequest` و`CompilationResponse`، بما فيهما `protocolVersion`, mode, source paths/texts, target وحقول النتائج.
- `AssistRequest` و`AssistResponse` وعناصر completion/help.
- أنواع diagnostics وsource spans وtokens وsymbol records ومخرجات intermediate representation.
- تحويل JSON والتحقق من الإصدارات والحقول الأساسية؛ يرفض factory الطلب غير الصالح بدل اعتباره استجابة ناجحة.

تختبر `compilation_protocol_test.dart` تحويلات compilation والتحقق من الطلب/الاستجابة، بينما تختبر `assist_protocol_test.dart` نماذج المساعدة. هذه اختبارات **شكل العقد في Dart** وليست بديلًا عن C executable integration test.

## 5. Compiler C ومسؤولية كل مرحلة

| الملف/الدالة | المدخل ← المخرج | المسؤولية |
|---|---|---|
| `src/main.c: main` | flags/stdin ← dispatch/exit code | `--protocol` و`--assist` يقرآن سطر JSON واحدًا ويمران عبر `c_run_protocol`؛ `--asm` يقرأ المصدر حتى EOF وينفذ مسار parse/semantic/TAC/Assembly المباشر؛ بلا وسيط يستخدم stdin كـprotocol افتراضيًا إذا لم يكن فارغًا |
| `src/protocol.c: c_run_protocol` | JSON text ← نتيجة تشغيل protocol | بوابة C بين CLI و`compiler_driver_run` |
| `src/driver/compiler_driver.c: compiler_driver_run` | request text ← response JSON | إذا كان `requestType` هو assist يمرر إلى handler؛ وإلا ينسق lexer/parser والتحليل وTAC وTyped IR وتوليد Assembly والتنفيذ الاختياري وartifact ثم يسلسل الاستجابة |
| `src/protocol/protocol_request.c: protocol_handle_assist` | طلب assist JSON ← استجابة completion/help JSON | يقرأ action وsourceText وoffset؛ يحسب prefix ونطاق الاستبدال، ويجيب من كتالوج المساعدة أو اقتراحات الإكمال |
| `src/protocol/protocol_request.c: protocol_request_executes`, `protocol_request_interactive` | payload ← أعلام التنفيذ | يستخرج اختيار التنفيذ والتفاعل المستخدم في مسار interpreter |
| `src/protocol/protocol_json.c` | JSON text/tokens ← قيم الحقول | يوفر تحليل JSON والبحث عن القيم التي تستخدمها معالجات الطلب |
| `src/protocol/protocol_response.c: protocol_response_init`, `protocol_add_*`, `protocol_serialize_response` | نتائج المراحل ← JSON response | تهيئة الاستجابة، إضافة التشخيصات والتوكنز والرموز وTAC والمخرجات وartifacts، وتسلسلها |
| `src/lexer.l` | source ← tokens + lexical diagnostics | Flex lexer للكلمات والرموز والقيم ومواقع المصدر |
| `src/parser.y` | tokens ← AST + syntax diagnostics | Bison grammar وقواعد بناء الشجرة |
| `src/ast.c` | عقد AST ← traversal/JSON/free helpers | تعريف/إدارة بنية الشجرة التي تستهلكها مراحل compiler |
| `src/semantic.c: c_analyze_semantics` | AST ← symbols/types/diagnostics | فحوص الدلالات وبناء نتائج الرمز ضمن القواعد المدعومة |
| `src/ir/tac.c: c_generate_tac` | AST ← `CTacResult` | خفض التعليمات والتعبيرات إلى Three-Address Code |
| `src/ir/typed_ir.c: protocol_generate_typed_ir` | AST ومعلومات semantic ← JSON ملخص Typed IR | يبني ملخصًا مرئيًا للوحدة والأنواع والرموز والكتل؛ ليس verifier شاملًا ولا backend مستقلًا |
| `src/runtime/interpreter.c: runtime_begin`, `runtime_execute_ast`, `runtime_end` | AST ومدخلات/خيارات تشغيل ← output/diagnostics | تنفيذ البرنامج داخل compiler، مع دعم الإدخال وفق request |
| `src/backend/x86_64/asm_x86_64*.c` | TAC وsemantic data ← NASM text | إخراج Assembly لهدف x86-64؛ لا يتعامل مباشرة مع Widgets ولا يساوي النص ملفًا تنفيذيًا |
| `src/backend/artifact_builder.c: artifact_build_native` | request/assembly/output path ← artifact metadata | ينشئ ملفات البناء المطلوبة ويعيد diagnostics عند فشل target/toolchain |
| `src/backend/toolchain.c: toolchain_run_process` | executable/args/environment ← exit/out/err | تشغيل أدوات البناء الخارجية وجمع نتائجها |

المسار العادي يخرج بيانات stages إلى protocol. بناء artifact يحدث فقط عند target مطلوب ومدعوم؛ تشغيل الناتج بعد ذلك مسؤولية runner داخل التطبيق. أسماء targets جزء من protocol، وليست أسماء لغات backend.

## 6. المكتبات والأدوات

### اعتماديات التطبيق والحزم

| الاعتمادية | مكان التعريف | الدور الفعلي |
|---|---|---|
| Flutter SDK | root `pubspec.yaml` (`sdk: flutter`) | widgets، themes، routing، text editing، keyboard shortcuts وdesktop app |
| Dart SDK | root `pubspec.yaml` (`^3.12.2`)؛ contracts SDK `>=3.12.2 <4.0.0` | لغة التطبيق والحزم، IO/process/JSON والاختبارات |
| `file_picker ^12.0.0` | root `pubspec.yaml` | اختيار ملف/مجلد عبر `FilePickerDocumentService` |
| `compiler_contracts` | root path dependency `packages/compiler_contracts` | نماذج والتحقق من compile/assist protocol |
| `flutter_test` | root dev dependency | widget/unit tests باستخدام test binding وfake services |
| `flutter_lints ^6.0.0` | root dev dependency | قواعد التحليل الساكن للدارت |
| `test ^1.26.2` | `packages/compiler_contracts/pubspec.yaml` dev dependency | اختبارات Dart العادية للحزمة |
| `cupertino_icons ^1.0.8` | root runtime dependency | معلنة كحزمة أيقونات؛ لم يظهر استعمال مباشر في ملفات التطبيق التي روجعت |
| `dart:io`, `dart:convert`, `dart:async` | Dart SDK القياسي | filesystem/platform/process، JSON UTF-8، وtimeouts/async orchestration |

### أدوات compiler والبناء

| الأداة | أين ولماذا تستخدم |
|---|---|
| C compiler (MSVC أو GCC/Clang) | ترجمة مصادر `packages/compiler_c/src` إلى `arabicc` بلغة C17 |
| CMake 3.16+ | تعريف target `arabicc` وتوليد scanner/parser وربط CTest |
| Flex / `win_flex` | توليد scanner C من `src/lexer.l`؛ CMake يضيف `--wincompat` على Windows |
| GNU Bison / `win_bison` | توليد parser C من `src/parser.y` |
| NASM | تحويل ملف Assembly إلى object للـnative target حيث تتوفر الأداة |
| GCC/linker | ربط object ومساعدات التشغيل إلى artifact؛ Windows release يضم MSYS2 UCRT64 toolchain |
| CTest | تشغيل أسماء الاختبارات المسجلة في `packages/compiler_c/CMakeLists.txt`: `arabicc_version`, `arabicc_help`, `arabicc_tac_golden`, `arabicc_asm_3ac_golden`, `arabicc_native_3ac_smoke`, `arabicc_artifact_security`؛ ويضيف اختبارات Dart integration عند العثور على Dart |
| Flutter/Dart CLI | pub get، format، analyze، test، build وتشغيل smoke verifier |
| GitHub Actions | CI للعقود/compiler/editor وبناء Linux؛ وworkflow إصدار منفصل يبني installers على runners أصلية |
| Inno Setup / `dpkg-deb` / `rpmbuild` / `pkgbuild` | إنشاء مُثبّت Windows وحزم Linux/macOS في pipeline الإصدار حسب النظام |

لا تنفذ Flex/Bison أو NASM أو CMake أثناء تحرير النص العادي. تشغيل compiler process منفصل عن build workflow؛ ويعتمد target native على الأدوات التي يضمّنها/يجدها backend.

## 7. الأدوات التشغيلية في `tool/`

| الأداة | الاستخدام |
|---|---|
| `verify_compiler_bundle.dart` | يرسل طلب protocol إلى executable محدد للتحقق أن compiler المضمّن يرد بشكل صالح |
| `packages/compiler_c/build.bat`, `packages/compiler_c/build.ps1` | بدائل Windows مبنية على GCC/Flex/Bison لتوليد مصادر parser/scanner وتجميع `arabicc.exe` ونسخه لمخرجات runner الموجودة؛ PowerShell يحاول إيجاد الأدوات عبر مسارات MSYS2 |
| `build_windows_debug.ps1` | بناء compiler عبر CMake وبناء Flutter Windows ثم وضع compiler بجانب ناتج runner |
| `build_windows_release.ps1` | فحوص Dart/Flutter الاختيارية، بناء C وFlutter، تضمين MSYS2 UCRT64 toolchain، smoke test، وإنشاء installer عبر Inno Setup اختياريًا |
| `environment_doctor.sh` | فحص توفر إصدارات وأدوات بيئة التطوير |
| `domain_self_test.dart` | تشغيل self-test لجزء domain أثناء التطوير |
| `tool/packaging/acsys360-windows.iss` | مواصفة ملفات ومكونات Inno Setup لمثبت Windows |

هذه scripts تنفذ خطوات محددة للـbuild/release؛ ليست runtime dependencies لازمة لمستخدم الحزمة بعد تثبيتها (باستثناء أدوات native التي يعلنها installer/target).

## 8. الاختبارات التي تثبت المسارات

| النطاق | ملفات الاختبار |
|---|---|
| widgets والrouting ولوحات النتائج وRTL وcompletion والـminimap | `test/widget_test.dart` |
| Document وWorkspace | `test/document_workspace_test.dart` |
| عمليات controller غير المتزامنة ومنع النتائج القديمة | `test/editor_controller_async_test.dart` |
| filesystem/path traversal CRUD | `test/local_workspace_repository_test.dart` |
| تشغيل compiler process وJSON/error/timeout | `test/process_compiler_repository_test.dart` |
| سياسة المسارات | `test/workspace_path_service_test.dart` |
| language service وdiagnostics | `test/editor_language_server_test.dart`, `test/arabic_language_service_test.dart` |
| highlighting | `test/arabic_syntax_highlighter_test.dart` |
| البحث والاستبدال والتنسيق والتعليق | `test/find_replace_test.dart`, `test/format_arabic_source_test.dart`, `test/toggle_line_comment_test.dart` |
| protocol Dart models | `packages/compiler_contracts/test/` |
| C compiler | `packages/compiler_c/tests/` وCTest |
| end-to-end bundle | `tool/verify_compiler_bundle.dart`، ويستدعى من workflow release بعد bundling |

توجد فجوة معروفة بين وجود وظيفة explorer وبين التغطية المرئية لها: عمليات repository مغطاة، لكن اختبارات widget لا تغطي كل قوائم السياق ومحاذاة أسماء الملفات في الشجرة. يجب ذكر هذا الفرق عند وصف نسبة الاختبار.

## 9. كيف تتبع تغييرًا جديدًا

1. ابدأ من الواجهة/الحدث، وحدد من يملك الحالة: Widget أم `EditorController` أم entity.
2. تتبع العقد إلى repository ثم datasource؛ لا تنقل filesystem أو process إلى Widget.
3. إذا عبر التغيير حد Dart/C، حدّث نماذج العقد في `compiler_contracts` وتنفيذ C واختبار protocol معًا.
4. اربط التعديل باختبار الوحدة أو widget أو integration المطابق، لا بمجرد وجود ملف.
5. حدّث هذا الدليل و[وثيقة الاعتماديات](./dependencies.md) إذا تغيرت بنية المسؤوليات أو tool/library.

للتسلسل التنفيذي راجع [المعمارية](./architecture.md)، ولأوامر المستخدم [اختصارات المحرر](./editor-shortcuts.md)، ولتوزيع الأدوات [بيئة البناء والإصدار](./reproducible-builds.md).
