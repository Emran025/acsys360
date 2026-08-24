# خارطة الطريق التنفيذية

## المرحلة 0: Foundation

تثبيت بنية workspace، قواعد Dart وFlutter، بروتوكول JSON، أدوات lint وformat، ونظام CI. معيار القبول هو أن يبني المشروع ويجتاز فحصًا فارغًا من دون منطق وهمي.

## المرحلة 1: Language Frontend

استخراج القواعد الرسمية إلى مواصفات lexer/parser، تنفيذ الرموز والمواقع، AST typed، ورسائل syntax diagnostics. معيار القبول هو اجتياز golden tests لعشرة برامج صحيحة وخاطئة.

## المرحلة 2: Semantic and Runtime

تنفيذ النطاقات وجدول الرموز والأنواع والثوابت والإجراءات، ثم interpreter deterministic لتشغيل البرنامج من المحرر. معيار القبول هو تطابق نتائج التشغيل مع fixtures وعدم تنفيذ برنامج يحوي أخطاء.

## المرحلة 3: IR and Target

توليد TAC ثم Assembly تعليمي موثق، وإنتاج artifact قابل للتشغيل وفق target محدد. معيار القبول هو trace قابل للمقارنة واختبار end-to-end.

## المرحلة 4: Editor MVP

بناء workspace، explorer، tabs، document state، فتح وحفظ وإنشاء الملفات، استدعاء CLI، ولوحات Tokens/AST/Diagnostics. معيار القبول هو دورة New → Edit → Save → Compile → View.

## المرحلة 5: Editor Productivity

إضافة الاختصارات، command palette، البحث والاستبدال، indentation، formatting، themes، Undo/Redo transaction-based، تعدد الملفات، وRun/Stop. معيار القبول هو اختبارات widget وcontroller لسير العمل الكامل.

## المرحلة 6: Release

إكمال التوثيق، أمثلة التكليف العشرة، إعداد portable build أو installer، التقرير، حماية main، وrelease workflow. معيار القبول هو build نظيف على target المعتمد وإمكانية تشغيل التسليم على جهاز جديد.
