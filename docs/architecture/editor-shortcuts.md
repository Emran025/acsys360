# مصفوفة اختصارات محرر Arabic360

هذه الوثيقة تحدد اختصارات التحرير التي ستنفذ فعليًا، وتفصل بين ما يخص النص، وما يخص Workspace، وما يحتاج إلى بنية غير موجودة بعد. المرجع السلوكي هو توثيق VS Code الرسمي، مع تكييف الأوامر للغة Arabic360 وبيئة Flutter Desktop.

## المبادئ

يجب أن تبقى الكتابة الطبيعية تحت سيطرة TextField، ولا يجوز أن يعيد Focus handler ابتلاع حرف أو Tab إلا عندما يكون لديه أمر مؤكد. كل تعديل نصي يجب أن يمر في مسار واحد حتى يدخل undo/redo ويحدّث diagnostics وcompletion. اختصارات Ctrl تُستخدم على Windows/Linux وCmd على macOS. اختصارات chord لا تُنفذ قبل وجود state machine صريح لها.

| الفئة | الاختصار | السلوك المطلوب | الحالة الحالية |
|---|---|---|---|
| ملف | Ctrl/Cmd+S | حفظ الملف الحالي | موجود |
| ملف | Ctrl/Cmd+Shift+S | حفظ باسم | موجود |
| ملف | Ctrl/Cmd+O | فتح ملف | منفذ |
| ملف | Ctrl/Cmd+W | إغلاق التبويب الحالي مع حماية dirty | منفذ مع حماية dirty |
| تحرير | Ctrl/Cmd+Z وCtrl/Cmd+Y | undo/redo | موجود |
| تحرير | Ctrl/Cmd+X/C/V | قص/نسخ/لصق TextField | Native TextField |
| تحرير | Ctrl/Cmd+Shift+K | حذف السطر | منفذ |
| تحرير | Ctrl/Cmd+Enter | إدراج سطر أسفل | منفذ |
| تحرير | Ctrl/Cmd+Shift+Enter | إدراج سطر أعلى | منفذ |
| تحرير | Alt+Up/Down | نقل السطر أو التحديد | منفذ |
| تحرير | Shift+Alt+Up/Down | نسخ السطر أو التحديد | منفذ |
| تحرير | Ctrl/Cmd+D | تحديد التكرار التالي، لا تكرار السطر | يجب فصل السلوك الحالي |
| تحرير | Ctrl/Cmd+/ | تعليق/فك تعليق الأسطر المحددة باستخدام `//` فقط، مع تعديل واحد قابل للتراجع | منفذ عبر `ToggleLineComment` مع widget regression |
| تحديد | Ctrl/Cmd+L | تحديد السطر الحالي | منفذ |
| تحديد | Ctrl/Cmd+Shift+L | تحديد كل التكرارات | المرحلة التالية |
| مسافة | Tab/Shift+Tab | قبول اقتراح أو indent/outdent | موجود، يحتاج regression أعمق |
| اقتراح | Ctrl/Cmd+Space | طلب completion | موجود |
| اقتراح | Tab | commit inline suggestion | موجود |
| اقتراح | Up/Down/Escape | تدوير/إلغاء الاقتراح | موجود |
| ملاحة | Ctrl/Cmd+PageUp/Down | التبويب السابق/التالي | منفذ |
| ملاحة | Ctrl/Cmd+1..9 | تحديد التبويب بالرقم | غير منفذ؛ لا يوجد binding حاليًا |
| ملاحة | F8/Shift+F8 | الخطأ التالي/السابق | منفذ |
| ملاحة | Ctrl/Cmd+F | بحث في الملف | موجود |
| ملاحة | Ctrl/Cmd+H | بحث واستبدال | موجود |
| لغة | F1 | مساعدة السياق | موجود |
| لغة | F2 | إعادة تسمية رمز عبر language service | يحتاج protocol action حقيقي |
| لغة | F12 | الانتقال للتعريف | يحتاج symbol locations في protocol |
| لغة | Ctrl/Cmd+. | quick fix | lamp منفذة؛ binding مباشر غير منفذ |
| عرض | Ctrl/Cmd+B | إخفاء/إظهار الشريط الجانبي | يحتاج state مستقل |
| عرض | Ctrl/Cmd+Plus/Minus | تكبير/تصغير النص في مكونات الواجهة | منفذ عبر `MediaQuery.textScaler`؛ الحدود 0.8–1.8 |
| عرض | Ctrl/Cmd+0 | إعادة مقياس النص إلى 100% | منفذ |
| عرض | Ctrl/Cmd+J | إخفاء/إظهار لوحة النتائج | منفذ عبر state وbinding |
| عرض | F5 | ترجمة وتشغيل interpreter | منفذ؛ Ctrl/Cmd+F5 للبناء native artifact |

## معيار القبول

لا يعد الاختصار منفذًا حتى يمر اختبار widget أو controller يثبت أن الاختصار يطبق التحويل على النص الصحيح، يحافظ على selection، يسجل تعديلًا واحدًا في undo stack، ولا يكسر الكتابة الطبيعية أو ghost completion. اختصارات Workspace تُختبر مع fake repository، واختصارات compiler تُختبر على protocol response حقيقي. التكبير العام يمرر قيمة واحدة إلى `MediaQuery.textScaler`؛ لا يجوز أن يضاعف `TextField` وgutter وminimap حجم الخط كل منها فوق القيمة العامة.
