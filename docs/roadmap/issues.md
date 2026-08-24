# سجل Issues المقترح

| ID | العنوان | يعتمد على | معيار القبول |
|---|---|---|---|
| FND-01 | تحويل المشروع إلى workspace منظم | — | بنية apps/packages تعمل و`flutter analyze` ينجح |
| FND-02 | تعريف عقد JSON بين المحرر والمترجم | FND-01 | request/response versioned مع golden fixtures |
| LEX-01 | تنفيذ Lexer وفق القواعد الكاملة | FND-02 | كل الرموز العربية والمواقع والأخطاء مغطاة |
| PAR-01 | تنفيذ Parser وAST typed | LEX-01 | كل productions الرسمية لها عقد واختبارات |
| SEM-01 | تنفيذ النطاقات وجدول الرموز | PAR-01 | كشف التكرار وغير المعرف وتضارب الأنواع |
| RUN-01 | تنفيذ Runtime/Interpreter | SEM-01 | تشغيل البرامج الصحيحة ومنع البرامج الخاطئة |
| IR-01 | توليد Three-Address Code | SEM-01 | TAC deterministic مع golden tests |
| ASM-01 | تحديد Target وتنفيذ Assembly | IR-01 | output موثق وقابل للتحقق على target |
| ED-01 | Workspace وFile Explorer | FND-01 | إنشاء/فتح/حفظ/تعدد الملفات |
| ED-02 | Tabs وDocument State | ED-01 | dirty state وclose confirmation صحيحان |
| ED-03 | Undo/Redo transaction engine | ED-02 | round-trip edits واختبارات حدودية |
| ED-04 | Command Registry والاختصارات | ED-02 | الأوامر تعمل من لوحة المفاتيح والواجهة |
| ED-05 | Editor surface وsyntax highlighting | ED-02, LEX-01 | كتابة وعرض RTL والعلامات الأساسية |
| ED-06 | Compiler integration | FND-02, ED-01 | compile يعرض JSON الحقيقي وdiagnostics |
| ED-07 | Panels وstage views | ED-06 | Tokens/AST/Symbols/TAC/Assembly/Output |
| ED-08 | Run/Stop وإدارة العمليات | RUN-01, ED-06 | منع التشغيل المتزامن وإظهار exit state |
| CI-01 | CI checks | FND-01 | format/analyze/test على كل PR |
| CI-02 | Build artifacts | CI-01, ASM-01, ED-08 | desktop artifact محفوظ في workflow |
| REL-01 | التقرير والأمثلة والتسليم | جميع المراحل | 10 أمثلة وتقرير وملف تشغيل موثق |

كل Issue يُنشأ لاحقًا كـ GitHub Issue مستقل باستخدام هذا القالب: السياق، الهدف، النطاق، الاعتماديات، معايير القبول، خطة الاختبار، المخاطر، وما هو خارج النطاق.
