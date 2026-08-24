# مرجع اختصارات VS Code

تمت مراجعة المراجع الرسمية في 24 أغسطس 2026 لبناء مجموعة مختصارات نافعة للمحرر، لا لنسخ كل أوامر VS Code بلا تمييز.

المصدر الأساسي: https://code.visualstudio.com/docs/reference/default-keybindings

المصدر السلوكي للتحرير: https://code.visualstudio.com/docs/editing/codebasics

مصدر قواعد keybindings والتعارضات: https://code.visualstudio.com/docs/configure/keybindings

## مجموعة الأولوية الأولى

تشمل المجموعة الأساسية الحفظ Ctrl/Cmd+S، حفظ باسم Ctrl/Cmd+Shift+S، التراجع Ctrl/Cmd+Z، الإعادة Ctrl/Cmd+Y أو Ctrl/Cmd+Shift+Z، القص والنسخ واللصق، حذف السطر Ctrl/Cmd+Shift+K، إدراج سطر أسفل Ctrl/Cmd+Enter، إدراج سطر أعلى Ctrl/Cmd+Shift+Enter، نقل السطر Alt+Up/Down، نسخ السطر Alt+Shift+Up/Down، والتعليق Ctrl/Cmd+/.

تشمل ملاحة النص Home وEnd وCtrl/Cmd+Home وCtrl/Cmd+End، تحديد السطر Ctrl/Cmd+L، إضافة cursor أعلى/أسفل، تحديد التكرارات Ctrl/Cmd+D وCtrl/Cmd+Shift+L، القفز للقوس المطابق Ctrl/Cmd+Shift+\\، زيادة/خفض المسافة Ctrl/Cmd+] وCtrl/Cmd+[، وطي/فتح الكتل.

تشمل البحث Ctrl/Cmd+F، الاستبدال Ctrl+H أو Cmd+Alt+F، النتائج التالية Enter والسابق Shift+Enter، البحث في الملفات Ctrl/Cmd+Shift+F، وإظهار المشاكل Ctrl/Cmd+Shift+M.

تشمل قدرات اللغة Ctrl/Cmd+Space للاقتراح، Tab لقبول inline suggestion، F1/Command Palette، F12 للتعريف، Shift+F12 للمراجع، F2 لإعادة التسمية، Ctrl+. للإصلاح السريع، وShift+Alt+F أو Ctrl+Shift+I لتنسيق المستند.

## ما يخص Arabic360

يجب تنفيذ الاختصارات ذات القيمة للمحرر النصي أولًا، مع احترام Ctrl في Windows/Linux وCmd في macOS. لا ينبغي إضافة Debug/Terminal/Source Control أو اختصارات تعتمد على خدمات غير موجودة في المنتج قبل بناء حدودها فعليًا. يجب أن تتعامل الاختصارات مع حالة focus ووجود ملف نشط ووجود اقتراح، حتى لا تمنع الكتابة الطبيعية أو تسرق Tab من المحرر.

المراجع الرسمية تصف أيضًا multi-cursor، column selection، البحث المتقدم، التنسيق عند الحفظ أو الكتابة، وkeybinding conflicts. هذه عناصر مستقلة يجب تنفيذها باختبارات منفصلة، لا إضافتها كأزرار شكلية.
