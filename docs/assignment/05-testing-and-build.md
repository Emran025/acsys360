# 05 — الاختبارات والبناء والتسليم

## 1. طبقات الاختبار

| الطبقة | ما تثبته |
|---|---|
| Lexer tests | تصنيف الكلمات والرموز والأعداد والخيوط والمحارف والتعليقات والأخطاء غير المغلقة |
| Parser tests | إنتاج AST للتعريفات والتعليمات والتعبيرات والوصول والحلقات والاستدعاءات |
| Semantic tests | الأنواع والنطاقات والثوابت والمراجع والسجلات والقوائم والأخطاء الموضعية |
| IR/TAC tests | تعليمات typed، labels، jumps، وقواعد التحقق من CFG الأساسي |
| Interpreter tests | الناتج والسلوك الحسابي والتحكم والإدخال والأخطاء التنفيذية |
| Native parity | مقارنة stdout بين interpreter وexecutable الناتج من dart-native |
| Protocol tests | round-trip JSON، الإصدار، قوائم النتائج، target، artifactDirectory، والأخطاء B001–B004 |
| Flutter widget tests | ghost text، رفض الاقتراح، الأسهم، اتجاه TextField، Enter indentation، المصباح، الأيقونة، والشجرة |
| CI build | format، analyze، test، Flutter desktop build، compiler bundle smoke test، والحزم الثلاث |

## 2. حالات native المثبتة

تغطي اختبارات parity الحالية الخيوط والمحارف والقيم المنطقية والحقيقية والثوابت، الإدخال الصحيح، if/else، repeat وrepeat-until، القوائم والسجلات، والإجراءات بالمرجع. ويجب إضافة أي construct جديد إلى parity قبل وصفه بأنه مدعوم في native backend.

## 3. فحوص الجودة

يجب أن ينجح الأمر التالي داخل حزمة compiler:

```text
dart format --output=none --set-exit-if-changed lib test
dart analyze
dart test
```

ويجب أن ينجح داخل تطبيق Flutter:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux --release
```

تستخدم GitHub Actions إصدار Flutter `3.44.5` نفسه المحدد في release workflow. ولا يكفي نجاح اختبار محلي على بيئة لا تحتوي Flutter SDK؛ عند غيابه يُذكر القيد ويُعتمد CI للتحقق من تطبيق Flutter.

## 4. البناء والنشر

يُبنى compiler عبر `dart compile exe` على كل runner، ثم يوضع بجانب التطبيق داخل `compiler/arabicc` أو `compiler/arabicc.exe`. ولجعل `dart-native` قابلًا للاستخدام من الحزمة الموزعة، يرفق workflow مجلد `compiler/dart-sdk`. يتم اختبار compiler المضمّن عبر protocol smoke، ثم تُرفع حزم Linux وWindows وmacOS إلى GitHub Release.

## 5. معايير قبول الإصدار

لا يصدر tag جديد إذا كان format أو analyze أو test أو desktop build فاشلًا. لا تعاد قائمة `artifacts` عند فشل البناء أو عدم وجود الملف. لا تُحذف tags السابقة، ولا يعاد استخدام tag منشور لمحتوى مختلف؛ كل تغيير جوهري يأخذ إصدارًا جديدًا.

## 6. سجل التحقق الحالي

| العنصر | الحالة المثبتة |
|---|---|
| protocol `0.4.0` | مدمج ومختبر |
| typed IR | مدمج مع اختبارات تحقق |
| native executable | مدعوم عبر `dart-native` للتركيبات المختبرة |
| release self-contained | منشور في v0.9.0 مع compiler وDart SDK |
| Flutter CI | format/analyze/test/build ناجحة في آخر run موثق بالمستودع |
| Assembly binary | غير مدعوم؛ المخرج الحالي نص NASM-like أكاديمي |
