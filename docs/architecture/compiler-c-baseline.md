# Baseline مقارنة compiler C مع compiler_core

## نطاق المقارنة

المرجع الحالي هو `packages/compiler_core`، ويحتوي على Lexer وParser وAST وSemantic وTAC وTyped IR وAssembly وRuntime وProjectCompiler وAssist. توجد عشرة fixtures نجاح في `examples/` واثنان للفشل في `examples/errors/`.

## الحالة عند بدء الإكمال

يوجد في `packages/compiler_c` Lexer وAST وParser محدود وSemantic محدود وTAC محدود وTyped IR محدود وbackend x86-64 NASM محدود. عدد اختبارات C هو ستة، وجميعها ناجحة، كما أن artifact integer صغيرًا جُمّع وشُغّل محليًا وداخل CI.

| مجال | مرجع Dart | C الحالي | شرط الانتقال التالي |
|---|---|---|---|
| fixtures النجاح | 10 | subset غير محدد بالكامل | تشغيل العشرة ومقارنة كل مرحلة |
| fixtures الفشل | 2 | اختبارات isolated فقط | مطابقة diagnostics وspans |
| AST | كامل | أولي | تغطية كل عقد compiler_core وserialization |
| Semantic | كامل مع scopes/project | أساسي | procedures/types/aliases/records/project |
| Runtime | Interpreter متعدد الميزات | غير منقول بالكامل | parity execution لكل fixtures |
| Assembly | NASM-like أكاديمي | NASM قابل للتجميع للـinteger subset | target/runtime helpers والأنواع والتدفق |
| Protocol | compile/project/assist `0.5.0` | stub يرفض عمدًا | round-trip كامل قبل الدمج |
| Flutter | يعمل بالمترجم المرجعي | غير مربوط | adapter بعد parity فقط |

## قاعدة القياس

لا تُحسب المرحلة مكتملة إلا إذا امتلكت تنفيذًا C واختبارًا مستقلًا، وfixture مقارنة مع المرجع، ونجاحًا على Linux CI. ولا يُسمح بتفعيل C في `ProcessCompilerRepository` قبل نجاح compile وassist وproject وnative smoke tests.
