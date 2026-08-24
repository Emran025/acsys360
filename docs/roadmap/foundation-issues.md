# Foundation Issues

## [FOUNDATION] تحويل القالب إلى مساحة مشروع مترجم ومحرر

**الهدف:** إزالة قالب Flutter التجريبي وإنشاء workspace منطقي يفصل editor desktop عن compiler core والعقود.

**معايير القبول:** توجد تطبيقات وحزم واضحة، لا توجد شاشة counter أو تعليقات القالب، ينجح `flutter analyze`، وتوثق شجرة المشروع في `docs/architecture/architecture.md`.

**الاختبارات:** تحليل ساكن، smoke test للتطبيق، والتحقق الآلي من وجود المسارات الأساسية.

## [CONTRACT] تعريف بروتوكول JSON بين المحرر والمترجم

**الهدف:** تثبيت request/response versioned يشمل diagnostics وtokens وAST وsymbols وTAC وassembly وartifacts.

**معايير القبول:** schema موثق، fixtures صحيحة وخاطئة، وإصدار البروتوكول ظاهر في كل نتيجة.

**الاختبارات:** serialization round-trip وcontract compatibility.

## [LANGUAGE] تنفيذ Lexer وParser وفق القواعد الرسمية

**الهدف:** دعم القواعد الموجودة في `language-rules.txt` دون استبدالها بصياغة C-like.

**معايير القبول:** كل production لها token/AST mapping، والمواقع دقيقة، ورسائل الأخطاء قابلة للعرض.

**الاختبارات:** unit tests وgolden AST لعشرة برامج متنوعة وحالات malformed input.

## [SEMANTIC] جدول الرموز والتحليل الدلالي

**الهدف:** تطبيق النطاقات والأنواع والثوابت والإجراءات والمعاملات والوصول المركب.

**معايير القبول:** كشف التعريف المكرر، الاستخدام قبل التعريف، تضارب الأنواع، المعاملات غير الصحيحة، ونطاقات الإجراءات.

**الاختبارات:** semantic fixtures موجبة وسالبة مع تشخيصات ثابتة.

## [EDITOR] بناء محرر Desktop متعدد الملفات شبيه بـ VS Code

**الهدف:** workspace explorer، tabs، فتح وحفظ، dirty state، أوامر، اختصارات، themes، RTL editor، Undo/Redo، diagnostics، panels، compile/run.

**معايير القبول:** دورة New → Edit → Save → Compile → View → Run تعمل على أكثر من ملف، ولا يختلط منطق العرض مع domain أو compiler.

**الاختبارات:** controller tests، widget tests، keyboard shortcut tests، وmulti-file integration test.

## [CI] GitHub Actions وحماية جودة الدمج

**الهدف:** فرض format/analyze/test/build على كل PR وتوفير desktop artifacts في release.

**معايير القبول:** workflow أخضر على main، يفشل عند lint أو test أو build، وartifact قابل للتنزيل.

**الاختبارات:** تشغيل workflow على PR تجريبي وتحقق smoke من compiler-editor protocol.
