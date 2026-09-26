# 02 — المعمارية والتنظيم الحالي

لشجرة الملفات ومسؤولية الوحدات والدوال ومسارات البيانات والأدوات والاختبارات بالتفصيل، راجع [خريطة الشيفرة](../architecture/project-code-map.md).

## 1. المبدأ العام

المحرر والمترجم عمليتان منفصلتان. تطبيق Flutter لا يضع Flex أو Bison أو التحليل الدلالي داخل طبقة العرض، والمترجم لا يعتمد على Widgets أو حالة Flutter. يربط `ProcessCompilerRepository` بين التطبيق وexecutable `arabicc` عبر JSON Protocol الإصدار `0.5.0`، بينما توفر `packages/compiler_contracts` النماذج والتحقق من الطلب والاستجابة.

## 2. طبقات تطبيق Flutter

| الطبقة | المسار | المسؤولية |
|---|---|---|
| Presentation | `lib/features/editor/presentation` | `EditorShell`، المحرر، التبويبات، مستكشف الملفات، لوحات التشخيص والنتائج، الاختصارات، minimap وWidgets |
| Controller | `lib/features/editor/presentation/controllers` | `EditorController` وتنسيق حالة الملفات والتبويبات والتحليل والتنفيذ |
| Domain | `lib/features/editor/domain` | كيانات `Document` و`Workspace` و`FileNode` و`CompilationResult`، عقود repositories، وuse cases للتحرير واللغة |
| Data | `lib/features/editor/data` | `LocalWorkspaceRepository`، `ProcessCompilerRepository`، مصادر مسارات workspace وإنشاء عملية compiler |
| Core | `lib/core` | الثوابت والأخطاء والخدمات العامة وواجهات use case الأساسية |
| Shared | `lib/shared` | الثيمات وWidgets المشتركة |

لا توجد حاليًا حزم `editor_domain` أو `editor_data` مستقلة؛ الطبقات domain وdata موجودة داخل feature المحرر في `lib/features/editor`.

## 3. طبقات المترجم C

يوجد backend الفعلي في `packages/compiler_c` ويُبنى إلى executable اسمه `arabicc`:

```text
main.c --protocol
    ↓
protocol.c: c_run_protocol()
    ↓
compiler_driver_run()
    ├─ protocol request parsing
    ├─ lexer.l عبر Flex → tokens
    ├─ parser.y عبر Bison → AST
    ├─ semantic.c → symbols وdiagnostics
    ├─ ir/tac.c → TAC → Typed IR summary
    ├─ runtime/interpreter.c عند طلب execution
    ├─ backend/x86_64/ → Assembly نصية من TAC
    └─ artifact_builder.c + toolchain.c عند طلب target مدعوم
         ↓
    protocol response → JSON stdout
```

يستقبل `arabicc` الطلب من stdin ويكتب استجابة واحدة إلى stdout. يدعم `--protocol` للتجميع والتحليل و`--assist` للمساعدة، ويدعم `--version` و`--help` للفحص التشغيلي.

## 4. العقد بين البرنامجين

يتضمن الطلب `protocolVersion` و`rootPath` و`sourcePaths` و`sourceTexts` و`mode`. ويمكن أن يضيف `entryPath` و`target` و`artifactDirectory`. تتضمن الاستجابة `success` و`diagnostics` و`tokens` و`syntaxTree` و`symbolTable` و`threeAddressCode` و`intermediateRepresentation` و`assembly` و`executionOutput` و`artifacts`.

يحوّل data layer الاستجابة إلى `CompilationResult` وكيانات التشخيص والرموز، ثم يعرضها controller في لوحات الواجهة. لا تقوم الواجهة بإعادة تحليل النص أو اختراع نتائج بديلة.

## 5. البناء والتغليف

يُبنى backend عبر CMake مع Flex وBison. على Windows يستخدم CMake خيار Flex `--wincompat` لتجنب تضمين `unistd.h` غير المتوفرة مع MSVC. ويستخدم lexer دالة نسخ نصية محمولة بدل `strdup` غير المضمونة مع C17، مما يحافظ على عمل Linux وWindows.

يضمّن `release.yml` executable `arabicc` داخل حزم Flutter Desktop للمنصات الثلاث. يختبر `verify_compiler_bundle.dart` العقد الفعلي بعد التغليف، ثم ينشر Release artifacts. أما `container.yml` فينشر صورة التطوير إلى GHCR.

## 6. حدود التنفيذ

لا يعني وجود backend C أن كل قواعد اللغة أو كل Assembly مدعومة بالكامل. التغطية الحالية هي subset موثق في grammar والاختبارات. ولا تُعد Assembly الناتجة binary قابلًا للتشغيل دون assembler مناسب. كما أن صورة التطوير في GHCR مخصصة لبيئة البناء ولا تستبدل حزم Desktop النهائية.

## References

[1]: https://github.com/Emran025/acsys360/tree/main/lib/features/editor "Editor feature layers"
[2]: https://github.com/Emran025/acsys360/tree/main/packages/compiler_c "C compiler implementation"
[3]: https://github.com/Emran025/acsys360/tree/main/packages/compiler_contracts "JSON protocol contracts"
[4]: https://github.com/Emran025/acsys360/blob/main/.github/workflows/release.yml "Release workflow"

المراجع: [1] [2] [3] [4]
