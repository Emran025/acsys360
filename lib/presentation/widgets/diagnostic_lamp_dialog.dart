import 'package:flutter/material.dart';

import '../../domain/entities/editor_diagnostic.dart';
import 'editor_dialogs.dart';

Future<EditorCodeAction?> showDiagnosticLampDialog(
  BuildContext context, {
  required EditorDiagnostic diagnostic,
}) => showDialog<EditorCodeAction>(
  context: context,
  builder: (context) => AppDialog(
    title: 'مساعدة المترجم',
    icon: Icons.lightbulb_outline_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(diagnostic.message, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Text('النوع: ${diagnostic.phase} · ${diagnostic.code}'),
        Text('الموضع: السطر ${diagnostic.line}، العمود ${diagnostic.column}'),
        const SizedBox(height: 16),
        Text(
          diagnostic.actions.isEmpty
              ? 'لا يوجد إصلاح تلقائي آمن.'
              : 'الإصلاحات المقترحة',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (diagnostic.actions.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final action in diagnostic.actions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_fix_high_outlined),
              title: Text(action.title),
              onTap: () => Navigator.pop(context, action),
            ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  ),
);
