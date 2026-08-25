# الاعتماديات والأدوات

## سياسة الاختيار

تُضاف dependency فقط إذا كان لها دور واضح يمكن اختباره وشرحه في التقرير. لا تستخدم الواجهة حزمة parser أو language service لإخفاء مراحل المترجم؛ مصدر grammar هو `compiler_core`، ومصدر النقل هو JSON protocol، ومكونات المحرر فوق Flutter primitives حيث يكفي ذلك.

| الأداة أو المكتبة | الإصدار المثبت | الغرض | موضع الاستخدام | سبب الاختيار والحد |
|---|---:|---|---|---|
| Flutter | `3.44.5` في CI وrelease | بناء محرر Desktop والاختبارات المرئية | `lib/`, `test/`, منصات `windows/linux/macos` | يوفر widgets وTextField وShortcuts وMediaQuery وtest harness؛ لا ينفذ parser أو semantic |
| Dart | إصدار SDK المرفق مع Flutter `3.44.5` | لغة المحرر ونواة compiler وCLI وruntime | كل ملفات `.dart` | لغة موحدة للـdomain والـcompiler وCLI مع قابلية تشغيل cross-platform |
| `file_picker` | كما هو مثبت في `pubspec.lock` | اختيار ملف أو مجلد حقيقي من النظام | `main.dart` وworkspace explorer | يعزل native picker؛ لا يملك حالة workspace ولا يقرأ grammar |
| `compiler_core` | path dependency محلية | Lexer وParser وAST وSemantic وTAC وTyped IR وAssembly وInterpreter وnative backend | `packages/compiler_core`، ويستخدم Lexer فقط في highlighter | يمنع تكرار lexical grammar؛ الواجهة لا تستدعي Parser أو Semantic |
| `compiler_contracts` | path dependency محلية | نماذج JSON typed والتحقق من protocol `0.5.0` | `packages/compiler_contracts` وprocess adapter | يثبت عقدًا مستقلاً بين executableين ويمنع خرائط غير موثقة |
| `flutter_test` | تابع لـFlutter SDK | widget tests وpump وkeyboard events | `test/` | يثبت RTL وTextField وshortcuts والـMinimap من منظور المستخدم |
| `package:test` | تابع للحزم | اختبارات compiler_core وcompiler_contracts | `packages/*/test` | سريع ومناسب للمراحل النقية بعيدًا عن Flutter |
| Dart `dart:io` | جزء من SDK | process/filesystem في حدود infrastructure وCLI | `lib/data`, `packages/compiler_core/bin`, backend | مقيد بحدود adapter؛ لا يدخل domain editor path policy |
| Cairo font asset | ملف محلي في `assets/fonts/Cairo.ttf` | عرض واجهة عربية مدمجة ومستقرة | `pubspec.yaml` وtheme | لا يعتمد على خط النظام، ويثبت الشكل في release |

## أدوات التطوير والتحقق

| الأداة | الغرض | قاعدة الاستخدام |
|---|---|---|
| `dart format` / `flutter analyze` | تنسيق وتحليل ساكن | يجب أن ينجحا قبل الدمج |
| `flutter test` | اختبارات المحرر والتكامل | يشمل widget وrepository وprotocol adapter |
| GitHub Actions | التحقق المتكرر وبناء Desktop | يستخدم Flutter `3.44.5` ومصفوفة Windows/Linux/macOS |
| `gh` | إدارة CI وtags وreleases | لا يُنشأ release قبل نجاح jobs المطلوبة |

## أدوات تمت دراستها ولم تُدمج

لم تُدمج حزم syntax-highlighting أو editor package لأن `ArabicSyntaxHighlighter` يعيد استخدام Lexer الحقيقي، ولأن undo/redo وRTL وghost text تحتاج تحكمًا مباشرًا في TextEditingValue. لم تُدمج parser generator مثل PEG؛ parser recursive-descent الحالي أسهل في ربط كل production برسالة syntax وAST، وسيُعاد تقييم القرار فقط مع benchmark واختبارات grammar جديدة.

## التتبع الأكاديمي

عند شرح dependency في التقرير يجب ذكر الاسم والإصدار والغرض والجزء المستخدم، ثم شرح السلوك الذي يظل مفهومًا للفريق. وجود package لا يُعد دليلًا على اكتمال وظيفة: `file_picker` لا يثبت workspace، وFlutter لا يثبت language service، و`compiler_core` لا يجعل Assembly binary ما لم يُستخدم assembler حقيقي.
