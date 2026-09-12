import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../domain/entities/compilation_result.dart';
import '../../controllers/editor_controller.dart';

class DiagnosticsPanelWidget extends StatefulWidget {
  final EditorController controller;
  const DiagnosticsPanelWidget({super.key, required this.controller});

  @override
  State<DiagnosticsPanelWidget> createState() => _DiagnosticsPanelWidgetState();
}

class _DiagnosticsPanelWidgetState extends State<DiagnosticsPanelWidget> {
  var _stage = 0;

  static const _stages = [
    'الأخطاء',
    'Tokens',
    'Syntax Tree',
    'Symbol Table',
    'Semantic',
    '3AC',
    'Typed IR',
    'Assembly',
    'التنفيذ',
    'Artifact',
  ];

  @override
  Widget build(BuildContext context) {
    final result = widget.controller.compilation;
    if (result == null) return const Center(child: Text('لا توجد نتيجة ترجمة'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var index = 0; index < _stages.length; index++)
                TextButton(
                  onPressed: () => setState(() => _stage = index),
                  style: TextButton.styleFrom(
                    foregroundColor: index == _stage
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: Text(_stages[index]),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _stageBody(result)),
      ],
    );
  }

  Widget _stageBody(CompilationResult result) => switch (_stage) {
    0 => _diagnostics(result),
    1 => _selectable(prettyJson(result.tokens)),
    2 => _selectable(
      result.syntaxTree == null
          ? 'لا توجد شجرة تحليل'
          : prettyJson(result.syntaxTree),
    ),
    3 => _selectable(prettyJson(result.symbols)),
    4 => _selectable(
      prettyJson(
        result.diagnostics
            .where((item) => item is Map && item['phase'] == 'semantic')
            .toList(),
      ),
    ),
    5 => _selectable(result.threeAddressCode.join('\n')),
    6 => _selectable(
      result.intermediateRepresentation == null
          ? 'لا يوجد Typed IR'
          : prettyJson(result.intermediateRepresentation),
    ),
    7 => _selectable(
      result.assembly.isEmpty ? 'لا يوجد مخرج Assembly' : result.assembly,
    ),
    8 => _selectable(
      result.executionOutput.isEmpty
          ? 'لا يوجد خرج تنفيذ'
          : result.executionOutput.join('\n'),
    ),
    9 => _artifacts(result),
    _ => const SizedBox.shrink(),
  };

  Widget _artifacts(CompilationResult result) {
    if (result.artifacts.isEmpty) {
      return _selectable(
        'لا يوجد artifact. استخدم Ctrl/Cmd+F5 بعد نجاح التحليل والبناء.',
      );
    }
    return _selectable(
      ['تم التحقق من artifact الناتج:', ...result.artifacts].join('\n'),
    );
  }

  Widget _diagnostics(CompilationResult result) {
    if (result.diagnostics.isEmpty) {
      return Center(
        child: Text(
          result.success ? 'تمت الترجمة والتنفيذ بنجاح' : 'فشلت الترجمة',
        ),
      );
    }
    return _selectable(
      result.diagnostics
          .map((diagnostic) {
            if (diagnostic is Map) {
              return '${diagnostic['phase'] ?? 'compiler'}: ${diagnostic['message'] ?? diagnostic}';
            }
            return '$diagnostic';
          })
          .join('\n'),
    );
  }

  Widget _selectable(String value) => SingleChildScrollView(
    padding: const EdgeInsets.all(8),
    child: SelectableText(
      value.isEmpty ? 'لا توجد بيانات لهذه المرحلة' : value,
    ),
  );
}

String prettyJson(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return '$value';
  }
}
