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
| `docs/architecture/architecture.md` | الطبقات وشجرة الملفات وعقد التكامل |
| `docs/roadmap/roadmap.md` | مراحل البناء ومعايير الانتقال |
| `docs/roadmap/issues.md` | سجل Issues المقترح والاعتماديات |
| `docs/testing/test-strategy.md` | اختبارات كل مرحلة ومعايير الجودة |
| `.github/workflows/ci.yml` | بوابة CI وبناء Desktop |

## المنتج المستهدف

يقدم المحرر مستكشف ملفات، مجلد workspace، تعدد الملفات والتبويبات، تحرير RTL، اختصارات، command palette، بحث واستبدال، تنسيق، themes، Undo/Redo transaction-based، تشخيصات، تشغيل وإيقاف، ولوحات Tokens وAST وSymbol Table وSemantic Diagnostics وTAC وAssembly وRuntime Output.

## أسلوب العمل

يُبنى كل تغيير في فرع مستقل ويُدمج عبر Pull Request بعد نجاح format وanalyze والاختبارات وبناء Desktop واختبار عقد JSON بين المحرر والمترجم. لا تُغلق أي Issue إلا بعد تنفيذ معايير القبول وخطة الاختبار المكتوبة فيها.

## الحالة الحالية

تم تحويل المستودع من قالب Flutter التجريبي إلى أساس موثق للمشروع: أضيفت Skill/RAG داخل المستودع، مراجع القواعد والتكليف، المعمارية المستهدفة، خارطة الطريق، سجل Issues، استراتيجية الاختبار، قالب Issue، وGitHub Actions. التنفيذ البرمجي التفصيلي للمحرر ونواة المترجم يبدأ بعد اعتماد هذا الأساس.
