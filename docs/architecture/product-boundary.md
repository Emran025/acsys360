# حدود المنتج والقرارات الهندسية

## الخلاصة

المشروع ليس محاولة لبناء Visual Studio أو لغة إنتاجية عامة. هو **بيئة تطوير تعليمية مكتبية للغة عربية محددة**، هدفها تنفيذ متطلبات مقرر المترجمات بوضوح، مع تجربة تحرير قريبة من VS Code في الوظائف الأساسية فقط. سيُقاس النجاح بصحة الترجمة، وضوح مراحلها، ثبات النتائج، وسهولة دورة العمل، لا بعدد الخصائص أو حجم الواجهة.

## ما يدخل داخل Boundary

| المجال | يدخل في المنتج | معيار الانتهاء |
|---|---|---|
| Workspace | مجلد مشروع واحد، ملفات لغة متعددة، إنشاء/فتح/حفظ/إعادة تسمية وحذف مع حماية الملفات غير المحفوظة | دورة عمل كاملة على ملفين أو أكثر |
| Editor | تبويبات، رقم السطر، RTL، تحديد ونسخ ولصق، indentation، بحث واستبدال، اختصارات، Undo/Redo | اختبارات controller وwidget مستقرة |
| Navigation | explorer هرمي، الملف النشط، فتح سريع، command palette صغيرة | كل أمر أساسي متاح من لوحة المفاتيح |
| Themes | Light/Dark وقياسات ألوان موحدة | لا تتغير دلالة diagnostics بين الثيمات |
| Compiler frontend | Lexer، Parser، AST typed، recovery، syntax diagnostics | تغطية كل القواعد الرسمية المخطط لها |
| Semantic | scopes، symbols، types، constants، procedures، arrays، records | رفض البرامج غير الصالحة قبل التوليد |
| Runtime | interpreter تعليمي deterministic مع input/output وlimits | نتائج fixtures مطابقة |
| Outputs | Tokens، AST، Symbol Table، semantic/syntax diagnostics، TAC، Assembly، runtime output | عقد JSON versioned ومخرجات قابلة للحفظ |
| Release | Linux أولًا للتطوير، ثم Windows إذا توفرت بيئة البناء، مع artifact واضح | smoke test على جهاز نظيف |

## ما يبقى خارج Boundary الإصدار الدراسي

لن نبني سوق إضافات، debugger كامل، language server بمعيار LSP، refactoring دلالي متقدم، package manager، نظام build عام، دعم لغات متعددة، تعاون لحظي، cloud workspace، أو مترجم native محسن للأداء. هذه خصائص قد تصلح لإصدار مستقبلي، لكنها تشتت عن متطلبات المقرر ولا تُضاف قبل اكتمال الأساس.

لا نعد بملف EXE أو Assembly أصلي متعدد المنصات قبل اختيار Target محدد. المسار الواقعي هو: interpreter موثق أولًا، ثم TAC، ثم Assembly تعليمي أو target واحد قابل للتشغيل. أي target إضافي يحتاج اختبارًا وأداة بناء وruntime خاصًا به.

## مستوى التشابه مع VS Code

| مستوى | سننفذه | لن ندّعيه |
|---|---|---|
| تحرير | نص متعدد الملفات، تبويبات، اختصارات، Undo/Redo، بحث، تنسيق بسيط | محرر نصوص كامل بامتدادات VS Code |
| مشروع | explorer وworkspace وdirty state وفتح سريع | workspace remote أو إدارة حزم |
| لغة | highlighting مبني على Lexer وقائمة كلمات ومشغلات | LSP كامل وcompletion دلالي متقدم |
| تشغيل | compile/run/stop وoutput وdiagnostics | debugger step-through وbreakpoints متقدمة |
| عرض الترجمة | تبويبات مراحل واضحة | منصة تحليل أداء أو profiling |

## الأدوات المختارة

| الأداة | القرار | السبب والحد |
|---|---|---|
| Flutter Desktop | أساسي | يدعم Windows وmacOS وLinux من قاعدة كود واحدة وفق الوثائق الرسمية [1] |
| Dart | أساسي لنواة المترجم والعقود | ينسجم مع Flutter ويتيح CLI مستقلًا واختبارات سريعة |
| `file_picker` | يضاف عند تنفيذ explorer | يوفر file/directory picker وsave dialog لسطح المكتب، والإصدار الحالي المنشور 12.0.0 [2] |
| `flutter_code_editor` | مرشح، لا يُعتمد تلقائيًا | يوفر highlighting وfolding وautocomplete وthemes، لكن folding محدود اللغات والتحليل التجريبي؛ سنستخدمه فقط إن خدم RTL والتكامل دون تقييد Undo/Redo [3] |
| `peg` | مؤجل | يمكن أن يولد PEG parser في Dart والإصدار المنشور 9.0.1 [4]، لكن recursive-descent يدوي أفضل مبدئيًا لشرح القواعد ورسائل الخطأ والتحكم في AST |
| Flutter `test`/`integration_test` | أساسي | اختبارات unit/widget/integration الرسمية تغطي الطبقات وسلوك التطبيق الكامل [5] |
| GitHub Actions | أساسي | فحص PR وبناء artifact، وليس بديلًا عن اختبار target محلي |

## سياسة الاعتماديات

لا تُضاف مكتبة لتجميل الشكل إذا كان Flutter يوفر الوظيفة. تُضاف dependency فقط إذا خفضت مخاطرة واضحة، مع تسجيل الإصدار والرخصة والمنصة والاستخدام. لا نستخدم parser generator قبل وجود grammar tests؛ الأداة لا تعفي الفريق من فهم Lexer/Parser ولا من فحص AST.

## ترتيب البناء الواقعي

نثبت العقد والنماذج أولًا، ثم نواة اللغة، ثم semantic/runtime، ثم TAC وtarget، ثم editor shell، ثم الإنتاجية والدمج. لا نبدأ بتصميم واجهة كبير قبل وجود compiler service يعيد نتيجة حقيقية؛ وإلا سنبني شاشة تعرض بيانات وهمية يصعب استبدالها.

## References

[1]: https://docs.flutter.dev/platform-integration/desktop "Flutter desktop support"
[2]: https://pub.dev/packages/file_picker "file_picker package"
[3]: https://pub.dev/packages/flutter_code_editor "flutter_code_editor package"
[4]: https://pub.dev/documentation/peg/latest/ "peg Dart documentation"
[5]: https://docs.flutter.dev/testing/integration-tests "Flutter integration testing"
