# 02 — المعمارية والتنظيم

## 1. المبدأ العام

المحرر والمترجم برنامجان منفصلان. لا يضع Flutter lexer أو parser أو semantic analyzer داخل طبقة العرض، ولا يقرأ المترجم حالة Widgets. يتواصل الطرفان عبر JSON protocol مشترك في حزمة `compiler_contracts`، بحيث يمكن اختبار compiler مستقلًا وإعادة بناء المحرر دون نقل منطق اللغة إلى الواجهة.

## 2. طبقات المحرر

| الطبقة | مسؤوليتها |
|---|---|
| Presentation | Widgets، الاختصارات، شريط النتائج، شجرة الملفات، الحالة المرئية، selection، ghost text |
| State | `EditorController`، إدارة Workspace والتبويبات والتشخيصات وعمليات التحرير |
| Domain | Use cases مثل التحليل والتنسيق والبحث والاستبدال، وواجهات repositories |
| Data | filesystem repository و`ProcessCompilerRepository` الذي يبدأ compiler executable ويرسل JSON |
| External | Flutter Desktop، file picker، process stdin/stdout، filesystem |

## 3. طبقات compiler_core

يمر الطلب في pipeline واضح:

```text
JSON protocol
    ↓
Lexer → Tokens/lexical diagnostics
    ↓
Parser → AST/syntax diagnostics
    ↓
Semantic analyzer → symbols/types/semantic diagnostics
    ↓
AST → Three-Address Code
    ↓
Typed IR validation
    ↓
Assembly text + Interpreter execution
    ↓
Optional dart-native emitter → Dart source → dart compile exe → artifact
```

كل مرحلة تملك اختبارات مستقلة ومخرجًا يمكن عرضه في لوحة النتائج. لا تعتمد Flutter على إعادة تخمين موضع الخطأ؛ `Diagnostic` يحمل phase وcode وmessage وSourceSpan.

## 4. العقد بين البرنامجين

الإصدار المعتمد هو `0.5.0`. يرسل الطلب `rootPath` و`sourcePaths` و`sourcetexts` و`mode` و`entryPath`، ويمكنه تحديد `target: none` أو `target: dart-native` و`artifactDirectory`. تعيد الاستجابة `success` و`diagnostics` و`tokens` و`syntaxTree` و`symbolTable` و`threeAddressCode` و`assembly` و`intermediateRepresentation` و`executionOutput` و`artifacts`.

في compile العادي يمكن أن يكون `mode` هو project لتجميع ملفات Workspace. أما Ctrl/Cmd+F5 فيستخدم `CompilationMode.active` ويرسل الملف النشط فقط، حتى لا يفشل native build بسبب تبويب آخر غير صالح أو ملف لا ينتمي إلى entry point الحالي.

## 5. سياسة الأسماء والملفات

يولد backend أسماء Dart داخلية لا تتعارض مع أسماء اللغة العربية، ويكتب مصدر Dart وexecutable داخل `artifactDirectory` الذي يحدده الطلب. لا يعاد مسار artifact وهمي. ويُفضّل أن يبقى المصدر المولد لأغراض التدقيق الأكاديمي، مع إمكانية تنظيفه لاحقًا وفق سياسة واضحة لا تحذف executable الصحيح قبل عرضه للمستخدم.

## 6. الحدود المتعمدة

المشروع لا يستخدم C-like syntax، ولا يخلط بين pseudo-assembly وbinary. ويدعم المشروع متعدد الملفات على مستوى التحليل والرموز المصدرة ضمن الحدود الموثقة؛ أما استدعاء إجراءات خارجية أثناء التنفيذ فيحتاج import/dependency grammar مستقلة قبل اعتباره مدعومًا بالكامل.
