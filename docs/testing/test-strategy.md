# استراتيجية الاختبار

## بوابة كل مرحلة

| المرحلة | اختبارات إلزامية |
|---|---|
| Foundation | تحليل ساكن، format check، تشغيل التطبيق، تحقق بنية workspace |
| Lexer | unit tests للرموز العربية والأعداد والسلاسل والمحارف والتعليقات والمواقع والأخطاء |
| Parser | golden AST لكل production، recovery بعد الخطأ، حدود الأقواس والفواصل |
| Semantic | تعريف مكرر، استخدام قبل التعريف، توافق الأنواع، scopes، parameters، arrays، records |
| Runtime | نتائج تنفيذ deterministic، input/output، branch، loops، call stack، منع التنفيذ عند diagnostics |
| TAC/Assembly | golden output، أسماء temporaries، labels، precedence، artifact validation |
| Editor domain | document edits، undo/redo، commands، tabs، dirty state، workspace tree |
| Editor widgets | explorer، tabs، editor، panels، themes، RTL، keyboard shortcuts |
| Integration | CLI process، JSON schema، compile/run، multi-file workspace، cancellation |
| Release | clean machine smoke test، desktop build، package contents، examples 01–10 |

## Fixtures

تنظم الأمثلة في `examples/valid`, `examples/syntax-errors`, و`examples/semantic-errors`. لا يكفي تغيير القيم داخل القاعدة نفسها؛ يجب أن تغطي الأمثلة أنواع البيانات، التعبيرات، الشروط، الحلقات الثلاث، الإجراءات، المصفوفات، السجلات، الإدخال والإخراج، وبرامج تجمع أكثر من قاعدة.

## معايير الجودة

لا تُقبل تحذيرات lint جديدة. يجب أن تكون التشخيصات ثابتة وقابلة للمقارنة، وأن يحتوي كل خطأ على المرحلة ورقم السطر والعمود والنطاق. يجب أن يفشل البرنامج برمز غير صفري عند وجود أخطاء، وألا يولد TAC أو Assembly قابلًا للتنفيذ لبرنامج غير صالح.
