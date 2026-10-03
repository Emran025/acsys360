# خط أساس تغطية الاختبارات

تم قياس التغطية محليًا عبر:

```sh
flutter test --coverage
```

## آخر قياس موثق

| المقياس | النتيجة |
|---|---:|
| اختبارات Flutter | 100 ناجحة |
| تغطية أسطر Dart | 2925 / 4100 = **71.34%** |
| ملفات Dart المغطاة بالكامل | 14 من 51 |
| اختبارات compiler C عبر CTest | 15 / 15 ناجحة |
| اختبارات compiler contracts | 6 ناجحة |

## ما تمت إضافته في هذه المرحلة

- اختبارات composition root و`ServiceLocator`.
- اختبارات workflow كاملة للـ`EditorController` تشمل workspace والحفظ والبحث/compiler/assist/build/run.
- اختبارات exceptions وfailures.
- اختبارات `SourceFilePolicy` و`DocumentFileService`.
- اختبارات `LocalWorkspacePathService` و`WorkspaceActions`.
- اختبارات `NativeArtifactRunner` للـoutput والإدخال التفاعلي والملف المفقود.
- اختبارات popovers والحوارات الرئيسية.
- إصلاح مسارات fixtures في اختبارات CMake بعد نقلها إلى شجرة `integration/`.
- إصلاح اختبار `ProcessCompilerRepository` ليستخدم `arabicc` على Linux و`arabicc.exe` على Windows.

## الفجوات المتبقية

لا تعني النسبة الحالية اكتمال التغطية. الملفات ذات الأولوية التالية ما زالت تحتاج حالات إضافية:

1. `EditorController`، خصوصًا أخطاء الحفظ والترجمة والتنفيذ وعمليات workspace.
2. `ProcessCompilerRepository`، خصوصًا timeout وJSON غير صالح وinteractive input وassist failures.
3. `EditorScreen` و`DiagnosticsPanel` ومسارات التفاعل الأقل استخدامًا.
4. `FilePickerDocumentService`، ويتطلب ذلك fake للـFilePicker platform بدل فتح dialog حقيقي.
5. حالات الحوارات والـwidgets المتخصصة مثل explorer context actions وeditor dialogs المتبقية.

الواجهات abstract مثل `ProgramRunner` لا تحتوي منطقًا تنفيذيًا مستقلًا؛ تغطيتها تكون عبر تطبيقاتها، لا عبر اختبار interface فارغ.

## بوابة الجودة

يشغّل CI `flutter test --coverage` لضمان استمرار إنتاج ملف `coverage/lcov.info`. لا تُرفع نسبة مستهدفة مصطنعة قبل استكمال الحالات الحرجة أعلاه؛ يجب أن ترتفع النسبة باختبارات سلوكية حقيقية لا باختبارات لمس الأسطر فقط.
