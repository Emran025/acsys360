import 'dart:io';

import 'package:flutter/material.dart';

Future<String?> showNewFileDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _NameDialog(
      title: 'ملف عربي جديد',
      icon: Icons.note_add_outlined,
      labelText: 'اسم الملف',
      hintText: 'main.arb',
      actionLabel: 'إنشاء',
    ),
  ).then(_normaliseName);
}

Future<String?> showNewFolderDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _NameDialog(
      title: 'مجلد جديد',
      icon: Icons.create_new_folder_outlined,
      labelText: 'اسم المجلد',
      hintText: 'src',
      actionLabel: 'إنشاء',
    ),
  ).then(_normaliseName);
}

Future<String?> showRenameDialog(
  BuildContext context, {
  required String currentName,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(
      title: 'إعادة تسمية العنصر',
      icon: Icons.drive_file_rename_outline,
      labelText: 'الاسم الجديد',
      initialValue: currentName,
      actionLabel: 'حفظ',
    ),
  ).then(_normaliseName);
}

String? _normaliseName(String? value) {
  final name = value?.trim();
  return name == null || name.isEmpty ? null : name;
}

Future<bool> confirmDiscardDialog(
  BuildContext context, {
  required String path,
}) async {
  final name = path.split(Platform.pathSeparator).last;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: 'تغييرات غير محفوظة',
          icon: Icons.warning_amber_rounded,
          content: Text('هل تريد إغلاق «$name» دون حفظ التغييرات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق دون حفظ'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> confirmDeleteDialog(
  BuildContext context, {
  required String path,
}) async {
  final name = path.split(Platform.pathSeparator).last;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AppDialog(
          title: 'حذف العنصر',
          icon: Icons.delete_outline,
          content: Text('هل تريد حذف «$name» نهائيًا؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ) ??
      false;
}

class AppDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    title: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(title)),
      ],
    ),
    content: SizedBox(width: 380, child: content),
    actions: actions,
  );
}

class _NameDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final String labelText;
  final String? hintText;
  final String? initialValue;
  final String actionLabel;

  const _NameDialog({
    required this.title,
    required this.icon,
    required this.labelText,
    this.hintText,
    this.initialValue,
    required this.actionLabel,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_nameController.text);

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    icon: widget.icon,
    content: TextField(
      controller: _nameController,
      autofocus: true,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check),
        label: Text(widget.actionLabel),
      ),
    ],
  );
}
