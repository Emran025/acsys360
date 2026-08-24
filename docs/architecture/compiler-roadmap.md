# خارطة المترجم الكامل لـ Arabic360

## المعيار

المترجم الكامل ليس مجرد parser يعيد AST أو interpreter يطبع الناتج. يجب أن يمر المصدر عبر lexer موثق، parser يبني AST/Parse Tree، تحليل أسماء ونطاقات وأنواع، فحص semantic، تمثيل وسيط typed، تحسينات محدودة قابلة للإثبات، توليد 3AC، توليد Assembly صحيح للهدف المحدد، ثم linking أو packaging ينتج artifact قابلًا للتشغيل. كل مرحلة يجب أن تملك diagnostics ومخرجات قابلة للعرض والاختبار.

## الحدود التي لا يجوز تجاوزها

قواعد اللغة العربية الموجودة في `.project/requirements-review/language-rules.txt` هي المصدر الوحيد للـ syntax. لا يجوز تحويل اللغة إلى C-like أو إضافة syntax غير منصوص عليه لتسهيل التنفيذ. أي غموض موثق مثل `=<` و`=>` مقابل أوصاف المقارنة يجب أن يُحسم باختبار وقرار معلن، لا بتطبيع صامت.

لا يجوز تسمية Assembly النصي أو ناتج Interpreter ملف EXE. artifact لا يعود إلى response إلا بعد إنشائه فعليًا والتحقق من وجوده وقابليته للتشغيل على target محدد. interpreter مفيد لاختبار semantics وpreview، لكنه ليس بديلًا عن backend.

## طبقات العمل

| الطبقة | مسؤوليتها | معيار القبول |
|---|---|---|
| Source model | إدارة source files ومواضع UTF-16/Unicode والتشخيص | offsets وline/column ثابتة في كل المنصات |
| Lexer | tokens الرسمية، literals، comments، punctuation، errors | لا token غير معروف يمر إلى parser دون diagnostic |
| Parser | Parse Tree/AST مع recovery محدود | أخطاء syntax لا تنتج AST مضللًا على أنه صالح |
| Names/scopes | symbols، declarations، procedures، parameters، aliases | duplicate/unknown/shadowing rules موثقة ومختبرة |
| Types | primitive وarray وrecord وalias وaccess | type identity وassignability وselectors دقيقة |
| Semantic | checks على statements وexpressions وcalls وcontrol flow | success لا يعود true عند أي semantic error |
| IR | typed TAC/CFG مع temporaries وlabels | كل operand وjump له نوع وtarget صحيح |
| Backend | Assembly للهدف المختار مع runtime contract | assembly syntax قابل للـ assembler أو فشل صريح |
| Artifact | compile/link/package وتشغيل smoke test | artifact path لا يظهر إلا بعد نجاح البناء والتشغيل |
| Protocol/UI | JSON versioned ومخرجات منظمة | Flutter يعرض payload typed ولا يعيد تحليل compiler |

## ترتيب التنفيذ

تبدأ المرحلة التالية بتثبيت model للـ source spans وtyped symbols، ثم فصل AST عن presentation JSON، ثم إضافة IR typed بدل النصوص الحرة، ثم اختبار كل operator وstatement على interpreter وIR معًا. بعد ذلك يُختار target واحد قابل للـ CI أولًا؛ لا يُدعم Windows/Linux/macOS كوعود مستقلة قبل امتلاك toolchain وتوقيع artifact لكل target.

المسار العملي المرشح للـ native artifact هو توليد مصدر target مضبوط من IR ثم استدعاء compiler معروف في بيئة build، مع حفظ source الوسيط وstdout/stderr وexit code. إذا لم يتوفر toolchain في target، تعيد الاستجابة diagnostic backend واضحًا ولا تعلن نجاحًا أو EXE وهميًا.

## معيار الإصدار

لا يُرفع رقم الإصدار عند إضافة classes أو مخرجات شكلية. الإصدار المقبول يحتاج أمثلة متنوعة تغطي كل production، اختبارات golden للـ tokens/AST/diagnostics/TAC، اختبارات runtime، اختبار artifact على CI، protocol compatibility، وفتح البرامج العشرة داخل المحرر دون سلوك مختلف عن CLI.
