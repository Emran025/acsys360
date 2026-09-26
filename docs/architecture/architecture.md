# معمارية acsys360 وبنية المشروع

## القرار المعماري الحالي

المشروع تطبيق Flutter Desktop مع backend مستقل للمترجم العربي مكتوب بلغة C. الواجهة لا تحتوي على Lexer أو Parser أو Semantic Analyzer. يبدأ المحرر executable المترجم ويرسل إليه طلبًا عبر JSON Protocol الإصدار `0.5.0`. هذا الفصل بين العمليتين يجعل المترجم قابلًا للبناء والاختبار والتضمين داخل حزم Desktop على Linux وWindows وmacOS.

## البنية الفعلية للمستودع

```text
acsys360/
├── lib/
│   ├── main.dart
│   ├── config/di/                 # حقن الاعتماديات
│   ├── core/                      # أخطاء وثوابت وخدمات عامة
│   ├── features/editor/
│   │   ├── data/
│   │   │   ├── datasources/       # تشغيل compiler ومسارات workspace
│   │   │   └── repositories_impl/ # تنفيذ مستودعات الملفات والمترجم
│   │   ├── domain/
│   │   │   ├── entities/          # Document وWorkspace وCompilationResult وغيرها
│   │   │   ├── repositories/      # العقود المجردة
│   │   │   └── usecases/          # اللغة العربية والتحرير وعمليات workspace
│   │   └── presentation/
│   │       ├── controllers/       # EditorController وحالة الشاشة
│   │       └── ui/                # الشاشة وWidgets والمحرر ولوحات النتائج
│   ├── routes/                    # التوجيه
│   └── shared/                    # الثيمات وWidgets المشتركة
├── packages/
│   ├── compiler_c/                # executable arabicc: Flex/Bison + C
│   └── compiler_contracts/        # نماذج وعقد JSON المشتركة في Dart
├── examples/                      # برامج عربية صحيحة وأمثلة أخطاء
├── docs/                          # المعمارية والاختبارات وخارطة الطريق
├── tool/                          # أدوات البيئة والتحقق وSmoke Test
├── .github/workflows/
│   ├── ci.yml                     # format/analyze/test وبناء Flutter
│   ├── release.yml                # بناء Desktop والمترجم والتغليف
│   └── container.yml              # نشر صورة GHCR لبيئة التطوير
└── المنصات/                       # android وios وlinux وmacos وwindows وweb
```

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
protocol.c: قراءة الطلب وبناء response
    ↓
Flex lexer.l → tokens + lexical diagnostics
    ↓
Bison parser.y → AST + syntax diagnostics
    ↓
ast.c + semantic.c → AST وsymbol table والتحقق الدلالي
    ↓
backend/x86_64/asm_x86_64.c ومكوّناته → Assembly نصية محدودة
    ↓
protocol response → JSON stdout
```

يُستخدم `packages/compiler_contracts` في Dart لتعريف نماذج الطلب والاستجابة والتحقق من العقد، بينما يظل `arabicc` executable مستقلًا عن Flutter. لا تُعد Assembly الناتجة binary؛ هي نص NASM ضمن النطاق المدعوم فقط.

## عقد التكامل

يرسل `ProcessCompilerRepositoryImpl` طلبًا يتضمن `protocolVersion` و`rootPath` و`sourcePaths` و`sourceTexts` و`mode`، ويمكنه إضافة `entryPath` و`target` و`artifactDirectory`. يعيد المترجم `success` و`diagnostics` و`tokens` و`syntaxTree` و`symbolTable` و`threeAddressCode` و`intermediateRepresentation` و`assembly` و`executionOutput` و`artifacts`.

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
