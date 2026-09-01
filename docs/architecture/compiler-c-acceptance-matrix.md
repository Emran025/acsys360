# مصفوفة قبول compiler C

## الهدف

تحدد هذه الوثيقة شروط اعتبار compiler C بديلًا إنتاجيًا للمترجم المرجعي الحالي. لا يُقبل الاستبدال بمجرد نجاح البناء؛ يجب أن يطابق compiler C عقد JSON `0.5.0`، ومخرجات المراحل، والتشخيصات، والتنفيذ، وملفات المشروع، ثم ينجح في التشغيل من واجهة Flutter.

## قاعدة الاستبدال

يبقى compiler المرجعي الحالي هو مسار الإنتاج إلى أن تتحقق جميع البوابات الموسومة `required`. لا يجوز لنسخة C أن تعيد `success: true` مع ناتج ناقص أو أن تعتمد على تنفيذ Dart خلفيًا.

| البوابة | شرط القبول | دليل الاختبار | الحالة |
|---|---|---|---|
| C17 build | بناء نظيف مع `-Wall -Wextra -Werror -pedantic` | CMake على Linux وCI | منجز للـmilestone الحالي |
| Lexer | جميع الكلمات والرموز والتعليقات والـspans مطابقة للمرجع | golden token fixtures | جزئي |
| Parser/AST | كل declarations/statements/expressions وقيم AST ومواضعها مطابقة | parser fixtures وAST JSON golden | جزئي |
| Diagnostics | نفس phase/code/severity/span والمعنى، مع رفض المصدر غير الصحيح | negative fixtures | جزئي |
| Semantic/scopes | aliases، records، procedures، parameters، returns، arrays، project symbols | semantic matrix | جزئي |
| TAC | temporaries، calls، branches، loops، labels، control-flow | TAC golden | جزئي |
| Typed IR | primitive/compound types وconversion وcontrol-flow validation | typed IR golden | جزئي |
| Runtime | نفس execution output وحدود الخطوات والأخطاء | parity fixtures | غير منجز |
| NASM | x86-64 NASM صحيح وقابل للتجميع والربط والتشغيل | `nasm` + `gcc` native test | integer subset فقط |
| Project mode | ملفات متعددة وexternal procedures/types وentry path | multi-file fixtures | غير منجز |
| Protocol compile | قراءة `CompilationRequest` وإرجاع كل حقول `CompilationResponse` | protocol round-trip tests | غير منجز؛ stub يرفض عمدًا |
| Protocol assist | completion/help بنفس الحقول والاستبدالات | assist parity tests | غير منجز |
| Flutter adapter | `ProcessCompilerRepository` يستخدم C دون تغيير domain/presentation | editor integration tests | غير منجز |
| Release | executable C مضمّن في Windows/Linux/macOS مع smoke tests | release matrix | غير منجز |

## ما هو منجز فعليًا الآن

المسار C الحالي مستقل وحقيقي: Lexer، AST، Parser محدود، Semantic محدود، TAC محدود، Typed IR محدود، وNASM backend محدود. ثبتت الاختبارات أن برنامجًا integer صغيرًا يولد Assembly، ويُجمع بـNASM، ويُربط، ويعمل على Linux. هذه النتيجة لا تعني اكتمال البديل.

## ترتيب الإغلاق الإلزامي

يُغلق العمل بالترتيب التالي: توسيع grammar وAST، ثم serialization، ثم Semantic وscopes وproject mode، ثم TAC وTyped IR وcontrol-flow، ثم runtime، ثم NASM runtime helpers والأنواع غير integer، ثم protocol compile/assist، ثم adapter الواجهة، ثم parity matrix وCI متعددة المنصات، وأخيرًا release.

## مبدأ عدم التراجع

لا يُحذف compiler المرجعي ولا تُنقل مسؤولية Flutter إلى C قبل وجود اختبار تكافؤ مقابل لكل fixture نجاح وفشل. إذا فشل C في حالة واحدة، يبقى المسار المرجعي فعالًا وتظهر الحالة كفشل CI لا كنجاح صامت.
