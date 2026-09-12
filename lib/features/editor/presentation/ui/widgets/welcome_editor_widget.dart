import 'package:flutter/material.dart';

class WelcomeEditorWidget extends StatelessWidget {
  final bool hasWorkspace;
  final Future<void> Function() onNewFile;
  final Future<void> Function() onOpenFile;
  final Future<void> Function() onOpenFolder;

  const WelcomeEditorWidget({
    super.key,
    required this.hasWorkspace,
    required this.onNewFile,
    required this.onOpenFile,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code_rounded, size: 52, color: colors.primary),
              const SizedBox(height: 14),
              Text(
                'Arabic360',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasWorkspace
                    ? 'اختر ملفًا من مستكشف المشروع للبدء'
                    : 'لم يتم فتح مجلد بعد',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 22),
              if (!hasWorkspace)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    WelcomeActionWidget(
                      icon: Icons.note_add_outlined,
                      label: 'ملف جديد',
                      onPressed: onNewFile,
                    ),
                    WelcomeActionWidget(
                      icon: Icons.file_open_outlined,
                      label: 'فتح ملف',
                      onPressed: onOpenFile,
                    ),
                    WelcomeActionWidget(
                      icon: Icons.folder_open_outlined,
                      label: 'فتح مجلد',
                      onPressed: onOpenFolder,
                    ),
                  ],
                )
              else
                Text(
                  'تصفح شجرة المشروع من مستكشف الملفات لفتح ملف .arb',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeActionWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const WelcomeActionWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}
