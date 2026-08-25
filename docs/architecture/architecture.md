# المعمارية وشجرة المشروع

## القرار

المشروع تطبيق Flutter Desktop أصله الحالي، وسيُعاد تنظيمه إلى مساحة عمل واضحة تحتوي على تطبيق المحرر وتطبيق CLI للمترجم وحزم منطق مستقلة. لا يُسمح بأن تعرف طبقة العرض تفاصيل Lexer أو Parser أو نظام الملفات مباشرة.

## الطبقات

| الطبقة | المسؤولية | ممنوع عليها |
|---|---|---|
| Presentation | النوافذ، التبويبات، الاختصارات، الثيمات، عرض الحالة | تحليل المصدر أو استدعاء `dart:io` مباشرة |
| Application/Domain | حالات الاستخدام، أوامر المستند، إدارة workspace، undo/redo، عقود الخدمات | الاعتماد على Flutter widgets |
| Data/Infrastructure | الملفات، العمليات، JSON، تشغيل المترجم، مراقبة التغييرات | وضع قواعد اللغة |
| Compiler Core | Lexer، Parser، AST، Symbol Table، Semantic، Runtime، IR، Target | الاعتماد على Flutter |

## شجرة الملفات المستهدفة

```text
apps/
  compiler_cli/
    bin/main.dart
  editor_desktop/
    lib/main.dart
    lib/presentation/{shell,editor,explorer,panels,theme}
packages/
  compiler_core/
    lib/src/{diagnostics,lexer,parser,ast,semantic,runtime,ir,target}
    test/{lexer,parser,semantic,runtime,ir}
  compiler_contracts/
    lib/{requests,responses,serialization}
  editor_domain/
    lib/src/{entities,usecases,commands,repositories}
    test/
  editor_data/
    lib/src/{filesystem,compiler_process,serializers}
    test/
examples/
  valid/
  syntax-errors/
  semantic-errors/
docs/
  architecture/
  grammar/
  roadmap/
  testing/
  report/
tool/
.github/
  ISSUE_TEMPLATE/
  workflows/
```

## محرر شبيه VS Code

يُعامل كل ملف كـ `Document` مستقل له URI ومحتوى ونسخة وdirty state ومكدس undo ومكدس redo. يدير `WorkspaceSession` الملفات المفتوحة والتبويبات والملف النشط والمجلد الجذري. تُنفذ عمليات التحرير عبر `EditCommand` تحمل النص السابق واللاحق ونطاق التعديل، بحيث يكون Undo وRedo قابلين للتوقع والاختبار. تحفظ الاختصارات في `CommandRegistry` بدل ربطها عشوائيًا بعناصر الواجهة.

يبدأ المحرر بشريط علوي للأوامر، مستكشف ملفات يساري، مساحة تبويبات مركزية، لوحة نتائج سفلية، وشريط حالة. تشمل الأوامر New/Open/Save/Save All/Close/Undo/Redo/Find/Replace/Format/Compile/Run/Stop، وتعرض لوحة النتائج تبويبات Tokens وAST وSymbol Table وDiagnostics وTAC وTyped IR وAssembly وRuntime Output وArtifact.

## حدود التكامل

يستدعي المحرر `compiler_cli` بعقد JSON versioned. يرسل المسار الجذري والملفات أو snapshot المشروع، ويستقبل نتيجة تحتوي على `protocolVersion`, `diagnostics`, `tokens`, `syntaxTree`, `symbolTable`, `threeAddressCode`, `intermediateRepresentation`, `assembly`, و`artifacts`. لا يُسمح بإظهار نتيجة ثابتة أو مصطنعة.
