class LanguageHelpEntry {
  final String keyword;
  final String title;
  final String description;
  final String syntax;

  const LanguageHelpEntry({
    required this.keyword,
    required this.title,
    required this.description,
    required this.syntax,
  });
}

class LanguageCatalog {
  static const entries = <LanguageHelpEntry>[
    LanguageHelpEntry(
      keyword: 'برنامج',
      title: 'بداية البرنامج',
      description: 'يعرّف اسم البرنامج ويحتوي كتلة التعريفات والتعليمات.',
      syntax: 'برنامج اسم_البرنامج؛ كتلة_برمجية.',
    ),
    LanguageHelpEntry(
      keyword: 'ثابت',
      title: 'تعريف الثوابت',
      description: 'يبدأ قسم تعريف قيمة ثابتة لا تتغير أثناء التنفيذ.',
      syntax: 'ثابت الاسم = القيمة؛',
    ),
    LanguageHelpEntry(
      keyword: 'نوع',
      title: 'تعريف نوع',
      description: 'يعرّف نوعًا مركبًا باسم عربي.',
      syntax: 'نوع الاسم = النوع_المركب؛',
    ),
    LanguageHelpEntry(
      keyword: 'متغير',
      title: 'تعريف المتغيرات',
      description: 'يعرّف متغيرًا أو مجموعة متغيرات بنوع بيانات.',
      syntax: 'متغير الاسم: نوع_البيانات؛',
    ),
    LanguageHelpEntry(
      keyword: 'اجراء',
      title: 'تعريف إجراء',
      description: 'يعرّف إجراءً بمعاملات اختيارية وكتلة تعليمات.',
      syntax: 'اجراء الاسم(المعاملات)؛ كتلة_الإجراء؛',
    ),
    LanguageHelpEntry(
      keyword: 'بالقيمة',
      title: 'معامل بالقيمة',
      description: 'يمرر المعامل إلى الإجراء كقيمة.',
      syntax: 'بالقيمة الاسم: النوع',
    ),
    LanguageHelpEntry(
      keyword: 'بالمرجع',
      title: 'معامل بالمرجع',
      description: 'يمرر المعامل إلى الإجراء كمرجع قابل للتعديل.',
      syntax: 'بالمرجع الاسم: النوع',
    ),
    LanguageHelpEntry(
      keyword: 'اطبع',
      title: 'الإخراج',
      description: 'يطبع متغيرًا أو محرفًا واحدًا أو أكثر.',
      syntax: 'اطبع(عنصر، عنصر) ',
    ),
    LanguageHelpEntry(
      keyword: 'اقرا',
      title: 'الإدخال',
      description: 'يقرأ قيمة إلى متغير وصول.',
      syntax: 'اقرا(متغير)',
    ),
    LanguageHelpEntry(
      keyword: 'اذا',
      title: 'الشرط',
      description: 'ينفذ تعليمة بناءً على تحقق تعبير منطقي.',
      syntax: 'اذا(شرط) فان تعليمة',
    ),
    LanguageHelpEntry(
      keyword: 'فان',
      title: 'فرع الشرط',
      description: 'يفصل الشرط عن التعليمة التي تنفذ عند تحقق الشرط.',
      syntax: 'اذا(شرط) فان تعليمة',
    ),
    LanguageHelpEntry(
      keyword: 'والا',
      title: 'الفرع البديل',
      description: 'ينفذ تعليمة بديلة عندما لا يتحقق الشرط.',
      syntax: 'والا تعليمة',
    ),
    LanguageHelpEntry(
      keyword: 'كرر',
      title: 'التكرار العددي',
      description: 'ينفذ تعليمة ضمن مجال تكرار محدد.',
      syntax: 'كرر(المتغير = البداية الى النهاية) تعليمة',
    ),
    LanguageHelpEntry(
      keyword: 'طالما',
      title: 'التكرار الشرطي',
      description: 'يكرر التعليمة ما دام الشرط صحيحًا.',
      syntax: 'طالما(شرط) استمر تعليمة',
    ),
    LanguageHelpEntry(
      keyword: 'استمر',
      title: 'جسم طالما',
      description: 'يفصل شرط طالما عن التعليمة المتكررة.',
      syntax: 'طالما(شرط) استمر تعليمة',
    ),
    LanguageHelpEntry(
      keyword: 'اعد',
      title: 'تكرار حتى',
      description: 'ينفذ التعليمة ثم يكررها حتى يتحقق الشرط.',
      syntax: 'اعد تعليمة حتى(شرط)',
    ),
    LanguageHelpEntry(
      keyword: 'من',
      title: 'بداية نوع قائمة',
      description: 'يفصل حجم القائمة عن نوع عناصرها.',
      syntax: 'قائمة[العدد] من النوع',
    ),
    LanguageHelpEntry(
      keyword: 'الى',
      title: 'نهاية مجال التكرار',
      description: 'يفصل بداية مجال كرر عن نهايته.',
      syntax: 'كرر(المتغير = البداية الى النهاية)',
    ),
    LanguageHelpEntry(
      keyword: 'اضف',
      title: 'خطوة التكرار',
      description: 'يحدد مقدار الزيادة الاختيارية في مجال كرر.',
      syntax: 'كرر(المتغير = البداية الى النهاية اضف الخطوة)',
    ),
    LanguageHelpEntry(
      keyword: 'حتى',
      title: 'نهاية تكرار حتى',
      description: 'يحدد شرط نهاية تكرار اعد.',
      syntax: 'اعد تعليمة حتى(شرط)',
    ),
    LanguageHelpEntry(
      keyword: 'صحيح',
      title: 'نوع صحيح',
      description: 'نوع بيانات للأعداد الصحيحة.',
      syntax: 'متغير الاسم: صحيح؛',
    ),
    LanguageHelpEntry(
      keyword: 'حقيقي',
      title: 'نوع حقيقي',
      description: 'نوع بيانات للأعداد الحقيقية.',
      syntax: 'متغير الاسم: حقيقي؛',
    ),
    LanguageHelpEntry(
      keyword: 'منطقي',
      title: 'نوع منطقي',
      description: 'نوع بيانات للقيم صح وخطأ.',
      syntax: 'متغير الاسم: منطقي؛',
    ),
    LanguageHelpEntry(
      keyword: 'حرفي',
      title: 'نوع حرفي',
      description: 'نوع بيانات للمحارف والسلاسل الرمزية وفق القاعدة.',
      syntax: 'متغير الاسم: حرفي؛',
    ),
    LanguageHelpEntry(
      keyword: 'خيط_رمزي',
      title: 'نوع خيط رمزي',
      description: 'نوع بيانات للسلاسل النصية.',
      syntax: 'متغير الاسم: خيط_رمزي؛',
    ),
    LanguageHelpEntry(
      keyword: 'قائمة',
      title: 'نوع قائمة',
      description: 'نوع مركب لقائمة ذات عدد محدد من العناصر.',
      syntax: 'قائمة[العدد] من نوع_البيانات',
    ),
    LanguageHelpEntry(
      keyword: 'سجل',
      title: 'نوع سجل',
      description: 'نوع مركب يتكون من حقول مسماة.',
      syntax: 'سجل(الحقل: النوع؛)',
    ),
    LanguageHelpEntry(
      keyword: 'صح',
      title: 'قيمة منطقية صحيحة',
      description: 'قيمة منطقية تمثل تحقق الشرط.',
      syntax: 'صح',
    ),
    LanguageHelpEntry(
      keyword: 'خطأ',
      title: 'قيمة منطقية خاطئة',
      description: 'قيمة منطقية تمثل عدم تحقق الشرط.',
      syntax: 'خطأ',
    ),
  ];

  static final keywordSet = {for (final entry in entries) entry.keyword};

  static final byKeyword = {for (final entry in entries) entry.keyword: entry};

  const LanguageCatalog._();
}
