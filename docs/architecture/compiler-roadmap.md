# أولويات توسيع المترجم

## الأساس الموجود

المترجم الحالي هو backend C في `packages/compiler_c/`، وليس خطة قيد الاختيار. يوفر executable عبر CMake، وprotocol `0.5.0`، وLexer/Parser وAST وتحليلًا دلاليًا، وTAC وTyped IR وInterpreter وNASM backend وartifact builder ضمن التغطية المحدودة الموجودة. انظر إلى [baseline الحالي](./compiler-c-baseline.md) و[مصفوفة القبول](./compiler-c-acceptance-matrix.md).

## أولويات التوسعة

تُعتمد الأولوية فقط بعد تحديد construct أو target غير مغطى باختبار، ثم يمر التغيير على الطبقات المتأثرة:

1. **تغطية اللغة:** إضافة fixtures لكل صياغة نحوية ودلالية معلنة، بما فيها حالات الخطأ.
2. **اتساق مراحل compiler:** تأكيد أن AST وdiagnostics وTAC وTyped IR وexecution وAssembly تصف المصدر نفسه، وعدم إخراج بيانات نجاح مضللة عند الفشل.
3. **توسعة project mode:** تغطية مصادر متعددة وentry path عبر protocol smoke، مع عدم مشاركة الرموز التي لا تسمح بها قواعد اللغة.
4. **استكمال targets:** بناء وتشغيل artifact لكل target تعلن الوثائق دعمه، والتحقق من متطلبات toolchain والتغليف على runner أصلي.
5. **Assist وعمليات الرموز:** أي completion أو help أو تعريف/إعادة تسمية جديد يجب أن يملك حقول protocol واختبارات، ولا يُقدّم على أنه LSP كامل دون تطبيق ذلك المعيار.
6. **عرض المحرر:** إبقاء النماذج typed في `compiler_contracts` وعرض الاستجابة في Flutter دون إعادة تنفيذ compiler logic.

## معايير القبول

- إضافة اختبار regression إلى الحزمة/الطبقة المناسبة لكل تغيير.
- تحديث `packages/compiler_c/README.md` وprotocol أو توثيق اللغة عندما يتغير الدعم.
- تشغيل CMake وCTest واختبارات protocol ذات الصلة.
- تحديث [مصفوفة حالة compiler C](./compiler-c-acceptance-matrix.md) على أساس الدليل الجديد.
- لا يوصف Assembly بأنه executable، ولا تُسجل artifacts قبل إنشائها والتحقق من نتيجتها.

هذه الأولويات ليست وعدًا باكتمال اللغة أو دعم جميع أنظمة التشغيل؛ يظل النطاق هو ما يثبته الكود والاختبار وسجل CI لكل إصدار.
