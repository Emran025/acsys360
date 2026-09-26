# خارطة الطريق والحالة الحالية

هذه خارطة على مستوى المستودع؛ الحالة أدناه تلخص التنفيذ الموجود ولا تستبدل اختبارات القبول أو بيان دعم قواعد اللغة.

## المراحل الحالية

| المسار | الحالة | الموجود |
|---|---|---|
| Foundation | منفذ | تطبيق Flutter منظم، طبقات editor feature، عقود JSON مشتركة، CMake وCI |
| Compiler frontend | منفذ جزئيًا | Lexer وParser/AST وsemantic analyzer في C؛ التغطية لا تعني اكتمال جميع قواعد اللغة |
| Runtime وIR | منفذ ضمن نطاق الاختبارات | Interpreter وTAC وTyped IR ونتائج البروتوكول |
| Assembly وartifact | منفذ ضمن targets محدودة | NASM نصي وartifact builder/toolchain لبعض التركيبات |
| Editor MVP | منفذ | workspace، explorer، مستندات وتبويبات، تحرير، تشغيل compiler وعرض المخرجات |
| Editor productivity | منفذ جزئيًا | RTL وMinimap والبحث والتنسيق والاختصارات والثيمات وcompletion/help؛ توجد أوامر أو تغطية اختبارية غير مكتملة |
| CI والتوزيع | موجود مع تفاوت بين المسارات | CI للعقود وcompiler وFlutter وبناء Linux؛ توجد workflows وسكربتات منفصلة لبناء/توزيع Desktop |

## الأولويات التالية

1. إضافة اختبارات widget مباشرة لمستكشف Workspace، خصوصًا أسماء العناصر في RTL وقوائم السياق وتدفق إنشاء/إعادة تسمية/قص/لصق/حذف.
2. تحديث مصفوفة دعم اللغة والـtargets عند إضافة كل construct، مع fixtures نجاح وفشل قابلة لإعادة الإنتاج.
3. توسيع اختبار الأوامر الموجودة وتحديث [مصفوفة الاختصارات](../architecture/editor-shortcuts.md) عند أي تغيير binding.
4. إكمال ميزات اللغة المتقدمة فقط عبر بروتوكول ومواقع رموز موثقة؛ لا يُدّعى F2 أو F12 أو LSP كامل قبل تنفيذها.
5. التحقق من كل منصة توزيع بتشغيل workflow واختبار bundle الفعلي؛ وجود مجلد runner وحده لا يكفي.

## مراجع الحالة

- [المعمارية](../architecture/architecture.md)
- [حدود المنتج](../architecture/product-boundary.md)
- [اختبارات compiler C](../architecture/compiler-c-acceptance-matrix.md)
- [استراتيجية الاختبار](../testing/test-strategy.md)
