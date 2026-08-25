# acsys360 — محرر ومترجم اللغة العربية

هذا المستودع هو نقطة البداية لبناء محرر لغة مكتبي شبيه بـ VS Code ومترجم مستقل للغة البرمجة العربية المحددة في ملفات المقرر. المشروع يتجه إلى Flutter Desktop، مع فصل Clean Architecture بين الواجهة، منطق المحرر، البنية التحتية، ونواة المترجم.

## نقطة الحقيقة المعرفية

قواعد اللغة ومتطلبات التكليف محفوظة داخل:

```text
.project/skills/arabic-compiler-project/
├── SKILL.md
└── references/
    ├── language-rules.txt
    └── assignment-requirements.txt
```

يجب قراءة الـ Skill قبل تعديل أي قاعدة أو مرحلة ترجمة. لا تُستبدل اللغة العربية بصياغة C-like ولا تُقبل نتائج ثابتة بدل نتائج ناتجة عن المصدر.

## الوثائق التنفيذية

| الوثيقة | الغرض |
|---|---|
| `docs/architecture/architecture.md` | الطبقات وعقد التكامل |
| `docs/architecture/product-boundary.md` | ما يدخل في النطاق وما يبقى خارج الادعاء |
| `docs/architecture/editor-shortcuts.md` | مصفوفة أوامر المحرر واختبارها |
| `docs/assignment/12-code-component-guide.md` | سبب وجود كل مكون ومسار بياناته وحدوده |
| `docs/roadmap/roadmap.md` | مراحل البناء ومعايير الانتقال |
| `docs/testing/test-strategy.md` | اختبارات كل مرحلة ومعايير الجودة |
| `.github/workflows/ci.yml` | بوابة CI وبناء Desktop |

## المنتج المستهدف

يقدم المحرر مستكشف ملفات، مجلد workspace، تعدد الملفات والتبويبات، تحرير RTL، اختصارات، command palette، بحث واستبدال، تنسيق، themes، Undo/Redo transaction-based، تشخيصات، تشغيل وإيقاف، ولوحات Tokens وAST وSymbol Table وSemantic Diagnostics وTAC وAssembly وRuntime Output.

## أسلوب العمل

يُبنى كل تغيير في فرع مستقل ويُدمج عبر Pull Request بعد نجاح format وanalyze والاختبارات وبناء Desktop واختبار عقد JSON بين المحرر والمترجم. لا تُغلق أي Issue إلا بعد تنفيذ معايير القبول وخطة الاختبار المكتوبة فيها.

## الحالة الحالية

المستودع يحتوي على محرر Flutter Desktop ومترجم `compiler_core` مستقل يتواصل مع المحرر عبر JSON protocol الإصدار `0.5.0`. تدعم النواة Lexer وParser/AST والتحليل الدلالي وSymbol Table وTAC وTyped IR وAssembly النصية وInterpreter، إضافة إلى backend `dart-native` محدود ومثبت باختبارات parity وartifact metadata.

يحتوي المحرر على workspace حقيقي وشجرة ملفات وتبويبات وتحرير وحفظ وتنسيق وتشخيصات وquick fixes محدودة وcompletion وhelp وghost text وsyntax/semantic highlighting وMinimap واختصارات التحرير وthemes ونتائج مراحل المترجم. توجد عشرة أمثلة نجاح مختلفة في `examples/`، وfixtures سلبية مستقلة في `examples/errors/` لاختبار syntax وsemantic diagnostics.

الإصدار المنشور حاليًا هو [`v0.14.0`](https://github.com/Emran025/acsys360/releases/tag/v0.14.0). لا تُسمى Assembly binary، ولا يُعلن `dart-native` مترجمًا عامًا لكل قواعد اللغة؛ كلا الحدين موثق ومغطى فقط ضمن subset المثبت.
