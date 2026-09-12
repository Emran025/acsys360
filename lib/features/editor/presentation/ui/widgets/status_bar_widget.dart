import 'package:flutter/material.dart';

import '../../controllers/editor_controller.dart';


class StatusBarWidget extends StatelessWidget {
  final EditorController controller;
  const StatusBarWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final dirty = controller.workspace.documents
        .where((document) => document.isDirty)
        .length;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.workspace.rootPath,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('تعديلات غير محفوظة: $dirty'),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
