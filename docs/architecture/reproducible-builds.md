# بيئة التطوير والبناء والإصدار

## الإجابة الدقيقة

نعم، توجد الآن صورة تطوير في `.devcontainer/Dockerfile` وإعداد `.devcontainer/devcontainer.json`. الصورة تثبت Ubuntu 24.04 وإصدار Flutter محددًا (`3.32.5`) وتثبت أدوات Linux Desktop. كما يثبت كل من CI وRelease workflow الإصدار نفسه صراحةً عبر `flutter-version: 3.32.5` بدل قناة `stable` المتحركة. هذا يجعل بيئة compiler والتحليل وبناء Linux متطابقة بين المطور وGitHub عند استخدام نفس الصورة.

لكن لا يصح استخدام صورة Linux واحدة لبناء Windows وmacOS native. لذلك تستخدم Release workflow runners أصلية لكل منصة: Ubuntu لـ Linux، Windows لـ Windows، وmacOS لـ macOS. هذا ليس تناقضًا؛ الصورة توحّد بيئة التطوير والتحقق، بينما native runners مطلوبة لتجميع artifact الأصلي للمنصة.

## المسارات

| الحدث | ما يحدث |
|---|---|
| Pull Request | checkout، Flutter `3.32.5`، pub get، format check، analyze، tests |
| Push إلى `main` | نفس الفحوصات وبناء Linux artifact للتحقق باستخدام Flutter `3.32.5` |
| تغيير `.devcontainer` على `main` | بناء صورة التطوير ونشرها إلى `ghcr.io/<owner>/<repo>/dev` مع SHA و`latest` |
| Tag من الشكل `vX.Y.Z` | بناء Linux/Windows/macOS على runners أصلية باستخدام Flutter `3.32.5`، ضغط artifacts، إنشاء GitHub Release وإرفاقها |
| بعد إضافة compiler CLI | يضاف smoke step يترجم fixtures ويمنع release عند فشل العقد أو الترجمة |

## الصلاحيات والأمان

يستخدم نشر GHCR `GITHUB_TOKEN` مع `packages: write`، ويستخدم نشر Release `contents: write`. لا توجد مفاتيح سرية في الملفات. يجب إبقاء package visibility خاصة إن كان المستودع خاصًا، وحماية main ومنع الدفع المباشر.

## معنى الترجمة التلقائية

في الوضع الحالي، الترجمة التلقائية تعني أن GitHub يبني تطبيق Flutter ويشغّل فحوصاته عند PR وtag. بعد إنشاء compiler داخل المستودع، يجب أن يضيف CI أمرًا صريحًا يترجم جميع fixtures العربية ويخزن JSON/TAC/Assembly كـ artifacts، ثم يمنع إصدارًا لا ينجح فيه compiler. لا نضع compiler وهميًا في workflow قبل وجوده.

## قيود يجب مراقبتها

إصدار Flutter في Dockerfile وDev Container يجب ترقيته معًا وبمراجعة مقصودة، لا عبر `latest`. كما يجب أن يطابق `pubspec.yaml` ومتطلبات CI. أداة `flutter_code_editor` اختيارية وليست شرطًا؛ إذا سببت قيودًا في RTL أو التحكم بالـ undo/redo نستبدلها بمحرر مخصص فوق Flutter primitives. أما `peg` فيبقى أداة توليد مؤجلة إلى أن تثبت اختبارات grammar أن فائدته أكبر من كلفة دمج parser generated.

## References

[1]: https://docs.github.com/actions/guides/publishing-docker-images "GitHub guide: Publishing Docker images"
[2]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry "GitHub Container registry"
[3]: https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow "GitHub matrix jobs"
[4]: https://docs.flutter.dev/platform-integration/desktop "Flutter desktop support"
