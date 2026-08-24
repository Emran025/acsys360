# خطة التحسين والتوسعة الدقيقة

## خط الأساس الفعلي

المستودع كان Flutter starter: تطبيق واحد في `lib/main.dart` بطول 122 سطرًا واختبار widget واحد خاص بعداد القالب، مع اعتماد Flutter و`cupertino_icons` و`flutter_lints` فقط. لا توجد نواة مترجم، ولا عقد بين عمليات، ولا workspace متعدد الملفات، ولا domain/data/presentation layers، ولا runtime أو مولد كود.

هذه ليست مشكلة يجب تغطيتها بميزات كثيرة دفعة واحدة؛ التحسين الصحيح هو إزالة القالب ثم إنشاء حدود ثابتة تستطيع استيعاب المراحل اللاحقة.

## التحسينات ذات الأولوية

| الأولوية | التحسين | لماذا الآن | دليل الإنجاز |
|---|---|---|---|
| P0 | تنظيف `main.dart` وإزالة counter | يمنع استمرار قالب غير متعلق بالمشروع | لا يبقى كود أو تعليق من القالب |
| P0 | إنشاء domain models للعقود والوثائق | يمنع ربط الواجهة بتفاصيل التنفيذ | unit tests بدون Flutter |
| P0 | بناء Document/Workspace state | أساس التعدد والتبويبات وdirty state | اختبارات state transitions |
| P0 | تحديد protocol JSON | نقطة الفصل بين compiler وeditor | schema وfixtures |
| P1 | Lexer/Parser القواعد الرسمية | القيمة الأكاديمية الأساسية | golden tests وdiagnostics |
| P1 | Symbol table وsemantic rules | منع نتائج ترجمة مضللة | fixtures موجبة وسالبة |
| P1 | compiler process adapter | دمج حقيقي لا mock | integration smoke test |
| P1 | editor shell وexplorer/tabs | تحويل التطبيق إلى أداة | widget tests |
| P2 | interpreter ثم TAC | تشغيل وعرض نتائج حقيقية | execution/TAC goldens |
| P2 | themes/shortcuts/find/format | إنتاجية قريبة من VS Code | command tests |
| P3 | assembly وartifact | تسليم متطلبات المقرر | target build على منصة واحدة |

## حدود الدقة

لا نخلط بين highlighting والتحليل النحوي. الـ Lexer هو مصدر token spans؛ المحرر يعرضها، لكن لا يعيد تنفيذها. ولا نخلط بين Save وCompile: الحفظ يحدّث الملف، والترجمة تأخذ snapshot معلومًا. ولا نخلط بين AST للعرض وAST typed للتحليل؛ العرض يستعمل serializer منفصلًا.

يجب أن يكون لكل عملية فشل محدد: الملف غير موجود، المصدر غير صالح، compiler غير متاح، timeout، أو artifact غير قابل للتنفيذ. لا تُحوّل هذه الحالات إلى رسالة عامة مثل "حدث خطأ".

## قرار التوسعات

تُؤجل language server، completion الدلالي، refactoring، debugging، plugin marketplace، remote workspace، التعاون الجماعي، package manager، وcross-platform native compiler. لا تدخل أي واحدة منها إلا بعد إغلاق P0–P3 ووجود اختبارات تحمي الأساس.

## Definition of Done

تُعد القدرة منتهية فقط عندما يكون لها domain contract، تنفيذ infrastructure أو compiler مناسب، واجهة مستخدم إن كانت مرئية، unit test، integration/widget test عند الحاجة، diagnostic واضح عند الفشل، تحديث للوثائق، وCI أخضر. لا يكفي أن تعمل في لقطة شاشة أو في جهاز المطور فقط.
