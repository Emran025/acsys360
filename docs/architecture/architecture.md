# معمارية acsys360 وبنية المشروع

## القرار المعماري الحالي

المشروع تطبيق Flutter Desktop مع backend مستقل للمترجم العربي مكتوب بلغة C. الواجهة لا تحتوي على Lexer أو Parser أو Semantic Analyzer. يبدأ المحرر executable المترجم ويرسل إليه طلبًا عبر JSON Protocol الإصدار `0.5.0`. هذا الفصل بين العمليتين يجعل المترجم قابلًا للبناء والاختبار والتضمين داخل حزم Desktop على Linux وWindows وmacOS.

## البنية الفعلية للمستودع

```text
acsys360/
├── assets/
│   ├── branding/arabic360.png     # شعار ملفات .arb وواجهة التطبيق
│   └── fonts/Cairo.ttf            # خط Cairo المسجل في Flutter
├── lib/                           # تطبيق Flutter/Dart
│   ├── main.dart                  # ArabicEditorApp وتهيئة MaterialApp والثيمات
│   ├── config/di/injection.dart   # ServiceLocator وتركيب الاعتماديات الفعلية
│   ├── core/
│   │   ├── constants/             # ألوان وثوابت التطبيق
│   │   ├── error/                 # Exceptions وFailures
│   │   ├── services/              # سياسة/عقد مسار workspace
│   │   ├── usecases/              # واجهة use case العامة
│   │   └── utils/                 # سلاسل ونصوص واجهة مشتركة
│   ├── features/editor/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── compiler_process_factory.dart
│   │   │   │   ├── file_picker_document_service.dart
│   │   │   │   ├── local_workspace_path_service.dart
│   │   │   │   └── native_artifact_runner.dart
│   │   │   └── repositories_impl/
│   │   │       ├── local_workspace_repository_impl.dart
│   │   │       └── process_compiler_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/          # Document/Workspace/FileNode/CompilationResult...
│   │   │   ├── repositories/      # WorkspaceRepository وProgramRunner
│   │   │   ├── services/          # document file service وسياسة امتدادات الملفات
│   │   │   └── usecases/          # تحرير/تنسيق/بحث/لغة/عمليات Workspace
│   │   └── presentation/
│   │       ├── controllers/editor_controller.dart
│   │       └── ui/
│   │           ├── screens/editor_screen.dart
│   │           └── widgets/       # explorer، editor، tabs، panels، minimap، dialogs...
│   ├── routes/app_router.dart     # home/editor routes مع controller محقون
│   └── shared/
│       ├── themes/app_theme.dart
│       └── widgets/collapsible_panel.dart
├── packages/
│   ├── compiler_contracts/        # Dart package: models/validation لـJSON protocol
│   │   ├── lib/src/               # compilation وassist requests/responses
│   │   └── test/                  # contract tests منفصلة عن widgets
│   └── compiler_c/                # backend مستقل يبنى إلى arabicc
│       ├── include/               # C public/internal module headers
│       ├── src/
│       │   ├── main.c             # CLI flags وstdin/stdout entry point
│       │   ├── protocol/          # JSON parse/request/response serialization
│       │   ├── lexer.l parser.y   # مصادر Flex/Bison
│       │   ├── ast.c semantic.c   # AST وsemantic analysis
│       │   ├── driver/            # تنسيق compile pipeline
│       │   ├── ir/                # TAC وTyped IR
│       │   ├── runtime/           # interpreter
│       │   └── backend/           # NASM x86_64 وartifact/toolchain
│       ├── tests/                 # C tests وDart protocol/example integration
│       └── CMakeLists.txt         # توليد scanner/parser والبناء وCTest
├── test/                          # Flutter unit/widget tests
├── examples/
│   ├── manual/                    # أمثلة يدويّة إيجابية وسلبية
│   ├── errors/                    # ملفات خطأ إضافية
│   └── *.arb                      # fixtures وأمثلة أخرى
├── tool/                          # bundle smoke، self-test، بناء Windows والتعبئة
├── docs/                          # architecture/assignment/roadmap/testing
├── .github/workflows/             # ci.yml وrelease.yml وcontainer.yml
├── android/ ios/ linux/ macos/
├── windows/ web/                  # Flutter platform runners
└── pubspec.yaml                   # تطبيق Flutter واعتمادياته والأصول
```

تفاصيل وظيفة كل ملف رئيسي والدوال/الأنواع المحورية موضحة في [دليل خريطة الشيفرة](./project-code-map.md). يشير هذا الرسم إلى ملفات المصدر، لا إلى مخرجات البناء أو الملفات المتولدة داخل `build/`.

## طبقات تطبيق Flutter

| الطبقة | الموقع | المسؤولية | الحدود |
|---|---|---|---|
| Presentation | `lib/features/editor/presentation` | Widgets، شاشة المحرر، التبويبات، المستكشف، الاختصارات، minimap ولوحات النتائج | لا تضع قواعد اللغة ولا تنشئ عملية compiler مباشرة |
| Controller | `lib/features/editor/presentation/controllers` | تنسيق حالة المحرر بين الواجهة وعمليات المجال | لا تحتوي على تفاصيل Flex/Bison |
| Domain | `lib/features/editor/domain` | كيانات `Document` و`Workspace` و`CompilationResult`، عقود repositories، وعمليات التحرير واللغة | مستقل عن Widgets وFlutter UI |
| Data/Infrastructure | `lib/features/editor/data` | قراءة الملفات، مسارات workspace، إنشاء عملية `arabicc`، إرسال stdin وقراءة stdout/stderr | لا يقرر قواعد grammar |
| Core/Shared | `lib/core` و`lib/shared` | الأخطاء والثوابت والخدمات العامة والثيمات والمكونات المشتركة | لا يربط domain بتفاصيل منصة واحدة |

## طبقات المترجم المستقل

يوجد التنفيذ الحالي في `packages/compiler_c`، وليس في مجلد `packages/compiler_core` الافتراضي القديم. يمر الطلب في المسار التالي:

```text
JSON request
    ↓
main.c (--protocol / --assist)
    ↓
protocol.c + protocol/: قراءة الطلب وتجميع response
    ↓
Flex lexer.l → tokens + lexical diagnostics
    ↓
Bison parser.y → AST + syntax diagnostics
    ↓
compiler_driver.c + ast.c + semantic.c → AST وsymbol table والتحقق الدلالي
    ↓
ir/tac.c → 3AC → ir/typed_ir.c → Typed IR
    ├── runtime/interpreter.c → execution output
    └── backend/x86_64/ → نص Assembly
          └── backend/artifact_builder.c + toolchain.c → artifact عند target مدعوم
    ↓
protocol response → JSON stdout
```

يُستخدم `packages/compiler_contracts` في Dart لتعريف نماذج الطلب والاستجابة والتحقق من العقد، بينما يظل `arabicc` executable مستقلًا عن Flutter. حقل `assembly` هو نص NASM؛ ويمكن لـbackend C إنشاء artifact تنفيذي منفصل عند طلب target مدعوم. القيمة `dart-native` اسم target في العقد ولا تعني وجود backend compiler مكتوب بـDart.

## عقد التكامل

يرسل `ProcessCompilerRepository` طلبًا يتضمن `protocolVersion` و`rootPath` و`sourcePaths` و`sourceTexts` و`mode`، ويمكنه إضافة `entryPath` و`target` و`artifactDirectory`. يعيد المترجم `success` و`diagnostics` و`tokens` و`syntaxTree` و`symbolTable` و`threeAddressCode` و`intermediateRepresentation` و`assembly` و`executionOutput` و`artifacts`.

يجب أن تكون النتيجة ناتجة عن المصدر الفعلي. لا يجوز للواجهة تركيب Tokens أو AST أو Diagnostics ثابتة بدل استجابة المترجم.

## البناء والتوزيع

يُبنى المترجم عبر CMake. على Windows يستخدم CMake خيار `--wincompat` عند تشغيل `win_flex` حتى لا يعتمد scanner المولد على `unistd.h`. ويستخدم lexer نسخًا نصية محمولة متوافقة مع C17 وMSVC. يتحقق `tool/verify_compiler_bundle.dart` من وجود استجابة JSON ناجحة بعد تضمين executable داخل حزمة Desktop.

يُنشئ `release.yml` حزم Linux وWindows وmacOS ويضمّن `arabicc` في كل حزمة. وينشر `container.yml` صورة التطوير إلى `ghcr.io/emran025/acsys360/dev:latest`.

## References

[1]: https://github.com/Emran025/acsys360 "acsys360 repository"
[2]: https://github.com/Emran025/acsys360/blob/main/packages/compiler_c/CMakeLists.txt "C compiler CMake configuration"
[3]: https://github.com/Emran025/acsys360/blob/main/.github/workflows/release.yml "Desktop release workflow"
[4]: https://github.com/Emran025/acsys360/blob/main/.github/workflows/container.yml "Development container workflow"

المراجع: [1] [2] [3] [4]
