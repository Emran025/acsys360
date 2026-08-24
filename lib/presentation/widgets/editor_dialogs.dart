import 'dart:io';

import 'package:flutter/material.dart';

Future<String?> showNewFileDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: 'ملف عربي جديد',
      icon: Icons.note_add_outlined,
      content: TextField(
        controller: nameController,
        autofocus: true,
        textDirection: TextDirection.rtl,
        decoration: const InputDecoration(
          labelText: 'اسم الملف',
          hintText: 'main.arb',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, nameController.text),
          icon: const Icon(Icons.add),
          label: const Text('إنشاء'),
        ),
      ],
    ),
  );
  nameController.dispose();
  return name?.trim().isEmpty ?? true ? null : name!.trim();
}

Future<String?> showNewFolderDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: 'مجلد جديد',
      icon: Icons.create_new_folder_outlined,
      content: TextField(
        controller: nameController,
        autofocus: true,
        textDirection: TextDirection.rtl,
        decoration: const InputDecoration(
          labelText: 'اسم المجلد',
          hintText: 'src',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, nameController.text),
          icon: const Icon(Icons.add),
          label: const Text('إنشاء'),
        ),
      ],
    ),
  );
  nameController.dispose();
  return name?.trim().isEmpty ?? true ? null : name!.trim();
}

Future<String?> showRenameDialog(
  BuildContext context, {
  required String currentName,
}) async {
  final nameController = TextEditingController(text: currentName);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: 'إعادة تسمية العنصر',
      icon: Icons.drive_file_rename_outline,
      content: TextField(
        controller: nameController,
        autofocus: true,
        textDirection: TextDirection.rtl,
        decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, nameController.text),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  nameController.dispose();
  final value = name?.trim();
  return value == null || value.isEmpty ? null : value;
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
