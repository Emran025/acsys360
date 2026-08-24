# بيئة التطوير والبناء والإصدار

## الإجابة الدقيقة

نعم، توجد الآن صورة تطوير في `.devcontainer/Dockerfile` وإعداد `.devcontainer/devcontainer.json`. الصورة تثبت Ubuntu 24.04 وإصدار Flutter محددًا (`3.44.5`) وتثبت أدوات Linux Desktop. كما يثبت كل من CI وRelease workflow الإصدار نفسه صراحةً عبر `flutter-version: 3.44.5` بدل قناة `stable` المتحركة. هذا يجعل بيئة compiler والتحليل وبناء Linux متطابقة بين المطور وGitHub عند استخدام نفس الصورة.

لكن لا يصح استخدام صورة Linux واحدة لبناء Windows وmacOS native. لذلك تستخدم Release workflow runners أصلية لكل منصة: Ubuntu لـ Linux، Windows لـ Windows، وmacOS لـ macOS. هذا ليس تناقضًا؛ الصورة توحّد بيئة التطوير والتحقق، بينما native runners مطلوبة لتجميع artifact الأصلي للمنصة.

## المسارات

| الحدث | ما يحدث |
|---|---|
| Pull Request | checkout، Flutter `3.44.5`، pub get، format check، analyze، tests |
| Push إلى `main` | نفس الفحوصات وبناء Linux artifact للتحقق باستخدام Flutter `3.44.5` |
| تغيير `.devcontainer` على `main` | بناء صورة التطوير ونشرها إلى `ghcr.io/<owner>/<repo>/dev` مع SHA و`latest` |
| Tag من الشكل `vX.Y.Z` | بناء Linux/Windows/macOS على runners أصلية باستخدام Flutter `3.44.5`، ترجمة `arabicc` إلى executable للمنصة، نسخه داخل bundle، ضغط artifacts، إنشاء GitHub Release وإرفاقها |
| فحص البيئة المحلية | تشغيل `bash tool/environment_doctor.sh --strict` على جهاز التطوير؛ ويمكن إضافة `--doctor` لطباعة `flutter doctor -v` |
| تحقق compiler المضمّن | يترجم Release workflow `packages/compiler_core/bin/arabicc.dart` عبر `dart compile exe` ثم يثبت الملف في `compiler/arabicc[.exe]` داخل حزمة المنصة قبل الضغط |

## الصلاحيات والأمان

يستخدم نشر GHCR `GITHUB_TOKEN` مع `packages: write`، ويستخدم نشر Release `contents: write`. لا توجد مفاتيح سرية في الملفات. يجب إبقاء package visibility خاصة إن كان المستودع خاصًا، وحماية main ومنع الدفع المباشر.

## معنى الترجمة التلقائية

تعني الترجمة التلقائية أن GitHub يبني تطبيق Flutter ويشغّل فحوصاته عند PR وtag، كما يبني compiler executable مستقلًا لكل منصة. حزمة Windows ليست ملفًا منفردًا؛ ZIP الإصدار يحتوي `acsys360.exe` وملفات Flutter المصاحبة ومجلد `compiler/arabicc.exe`. لذلك يعمل الإصدار دون Dart SDK أو `dart run` أو مصدر المستودع. يبقى fallback التطوير في `main.dart` مخصصًا للتشغيل من checkout فقط.

## قيود يجب مراقبتها

إصدار Flutter في Dockerfile وDev Container وCI وRelease يجب ترقيته معًا وبمراجعة مقصودة، لا عبر `latest`. الإصدار الحالي المعتمد هو `3.44.5`، ويأتي معه Dart `3.12.2` وفق [سجل إصدارات Flutter الرسمي][5]. يمكن تشغيل `bash tool/environment_doctor.sh --strict` على جهاز التطوير للتحقق من ذلك. كما يجب أن يطابق `pubspec.yaml` ومتطلبات CI. أداة `flutter_code_editor` اختيارية وليست شرطًا؛ إذا سببت قيودًا في RTL أو التحكم بالـ undo/redo نستبدلها بمحرر مخصص فوق Flutter primitives. أما `peg` فيبقى أداة توليد مؤجلة إلى أن تثبت اختبارات grammar أن فائدته أكبر من كلفة دمج parser generated.

## References

[1]: https://docs.github.com/actions/guides/publishing-docker-images "GitHub guide: Publishing Docker images"
[2]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry "GitHub Container registry"
[3]: https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow "GitHub matrix jobs"
[4]: https://docs.flutter.dev/platform-integration/desktop "Flutter desktop support"
[5]: https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json "Flutter official Linux release metadata"
