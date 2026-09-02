# مصفوفة قبول compiler C

## الهدف

تحدد هذه الوثيقة شروط اعتبار compiler C بديلًا إنتاجيًا للمترجم المرجعي الحالي. لا يُقبل الاستبدال بمجرد نجاح البناء؛ يجب أن يطابق compiler C عقد JSON `0.5.0`، ومخرجات المراحل، والتشخيصات، والتنفيذ، وملفات المشروع، ثم ينجح في التشغيل من واجهة Flutter.

## قاعدة الاستبدال

يبقى compiler المرجعي الحالي هو مسار الإنتاج إلى أن تتحقق جميع البوابات الموسومة `required`. لا يجوز لنسخة C أن تعيد `success: true` مع ناتج ناقص أو أن تعتمد على تنفيذ Dart خلفيًا.

| البوابة | شرط القبول | دليل الاختبار | الحالة |
|---|---|---|---|
| C17 build | بناء نظيف مع `-Wall -Wextra -Werror -pedantic` | CMake على Linux وCI | منجز للـmilestone الحالي |
| Lexer | جميع الكلمات والرموز والتعليقات والـspans مطابقة للمرجع | golden token fixtures | جزئي |
| Parser/AST | كل declarations/statements/expressions وقيم AST ومواضعها مطابقة | parser fixtures وAST JSON golden | fixtures السليمة مكتملة؛ AST golden جزئي |
| Diagnostics | نفس phase/code/severity/span والمعنى، مع رفض المصدر غير الصحيح | negative fixtures | جزئي |
| Semantic/scopes | aliases، records، procedures، parameters، returns، arrays، project symbols | semantic matrix وfixtures 07/08 | procedure parameter scopes وby-value/by-reference validation منجز؛ aliases/records/project symbols متبقية |
| TAC | temporaries، calls، branches، loops، labels، control-flow | CTest وTAC generation على AST | control-flow الأساسي منجز؛ golden parity جزئي |
| Typed IR | primitive/compound types وconversion وcontrol-flow validation | CTest وTyped IR generation | control-flow الأساسي منجز؛ compound types وgolden parity جزئي |
| Runtime | نفس execution output وحدود الخطوات والأخطاء | parity fixtures | غير منجز |
| NASM | x86-64 NASM صحيح وقابل للتجميع والربط والتشغيل | `nasm` + `gcc` native test على arithmetic وif وrepeat وprocedure call وfixtures 07/08 | integer + comparison/control-flow/repeat وprocedure ABI بالقيمة/المرجع؛ الأنواع المركبة وreturns متبقية |
| Project mode | ملفات متعددة وexternal procedures/types وentry path | multi-file fixtures؛ validation لكل source unit | تحليل الوحدات الإضافية منجز؛ cross-file symbols/types وentry selection متبقية |
| Protocol compile | قراءة `CompilationRequest` وإرجاع كل حقول `CompilationResponse` | CTest protocol smoke وproject validation وDart bundle smoke | v0.5.0 وTAC/IR/NASM وSymbol spans منجزة؛ cross-file aggregation وDart bundle smoke متبقية |
| Protocol assist | completion/help بنفس الحقول والاستبدالات | C executable `--assist` contract smoke؛ parity التفصيلي متبقٍ | endpoint منجز؛ parity جزئي |
| Flutter adapter | `ProcessCompilerRepository` يستخدم C دون تغيير domain/presentation | editor integration tests وDart bundle smoke | executable متوافق مع smoke؛ اختيار bundle والتكامل النهائي متبقٍ |
| Release | executable C مضمّن في Windows/Linux/macOS مع smoke tests | release matrix | غير منجز |

## ما هو منجز فعليًا الآن

المسار C الحالي مستقل وحقيقي: Lexer، AST، Parser يغطي fixtures السليمة العشرة، Semantic للتعريفات والتدفق والاستدعاءات، protocol v0.5.0 أساسي، وNASM backend integer محدود. ثبتت الاختبارات أن برنامجًا integer صغيرًا يولد Assembly، ويُجمع بـNASM، ويُربط، ويعمل على Linux. هذه النتيجة لا تعني اكتمال البديل.

## ترتيب الإغلاق الإلزامي

يُغلق العمل بالترتيب التالي: توسيع grammar وAST، ثم serialization، ثم Semantic وscopes وproject mode، ثم TAC وTyped IR وcontrol-flow، ثم runtime، ثم NASM runtime helpers والأنواع غير integer، ثم protocol compile/assist، ثم adapter الواجهة، ثم parity matrix وCI متعددة المنصات، وأخيرًا release.

## مبدأ عدم التراجع

لا يُحذف compiler المرجعي ولا تُنقل مسؤولية Flutter إلى C قبل وجود اختبار تكافؤ مقابل لكل fixture نجاح وفشل. إذا فشل C في حالة واحدة، يبقى المسار المرجعي فعالًا وتظهر الحالة كفشل CI لا كنجاح صامت.
