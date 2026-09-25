import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../domain/entities/compilation_result.dart';
import '../../controllers/editor_controller.dart';

class DiagnosticsPanelWidget extends StatefulWidget {
  final EditorController controller;
  final List<String> inputNames;
  final String inputType;
  final int inputRequestSequence;
  final ValueChanged<Map<String, String>>? onSubmitInputs;
  final VoidCallback? onCancelInputs;

  const DiagnosticsPanelWidget({
    super.key,
    required this.controller,
    this.inputNames = const [],
    this.inputType = 'غير معروف',
    this.inputRequestSequence = 0,
    this.onSubmitInputs,
    this.onCancelInputs,
  });

  @override
  State<DiagnosticsPanelWidget> createState() => _DiagnosticsPanelWidgetState();
}

class _DiagnosticsPanelWidgetState extends State<DiagnosticsPanelWidget> {
  var _stage = 0;
  final Map<String, TextEditingController> _inputFields = {};

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
  void dispose() {
    for (final field in _inputFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DiagnosticsPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inputNames.isEmpty && widget.inputNames.isNotEmpty) {
      _stage = 8;
    }
    if (oldWidget.inputRequestSequence != widget.inputRequestSequence) {
      for (final field in _inputFields.values) {
        field.clear();
      }
    }
  }

  void _syncInputFields() {
    final names = widget.inputNames.toSet();
    for (final name in _inputFields.keys.toList()) {
      if (!names.contains(name)) _inputFields.remove(name)?.dispose();
    }
    for (final name in names) {
      _inputFields.putIfAbsent(name, TextEditingController.new);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.controller.compilation;
    if (result == null) {
      if (widget.controller.error != null) {
        return _selectable('فشل التنفيذ:\n${widget.controller.error}');
      }
      return widget.inputNames.isEmpty
          ? const Center(child: Text('لا توجد نتيجة ترجمة'))
          : _inputRequest();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              for (var index = 0; index < _stages.length; index++)
                _stageTab(context, index: index, label: _stages[index]),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _stageBody(result)),
      ],
    );
  }

  Widget _stageTab(
    BuildContext context, {
    required int index,
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;
    final active = index == _stage;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 2),
        child: Material(
          color: active
              ? colors.primaryContainer.withValues(alpha: .42)
              : Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _stage = index),
            hoverColor: colors.primary.withValues(alpha: .08),
            splashColor: colors.primary.withValues(alpha: .14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? colors.primary : Colors.transparent,
                    width: active ? 3 : 0,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 5),
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
            .where((item) => item.phase == 'semantic')
            .map((item) => item.toJson())
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
    8 =>
      widget.inputNames.isNotEmpty
          ? _inputRequest()
          : _selectable(
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

  Widget _inputRequest() {
    _syncInputFields();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'التنفيذ متوقف بانتظار الإدخال',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('النوع المطلوب: ${widget.inputType}'),
          const SizedBox(height: 4),
          const Text(
            'أدخل قيمة الطلب الحالي فقط ثم اضغط «إرسال»؛ سيستمر البرنامج حتى طلب الإدخال التالي.',
          ),
          const SizedBox(height: 8),
          for (final name in widget.inputNames)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _inputFields[name],
                decoration: InputDecoration(
                  labelText: name,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancelInputs,
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => widget.onSubmitInputs?.call({
                  for (final name in widget.inputNames)
                    name: _inputFields[name]!.text.trim(),
                }),
                child: const Text('إرسال'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _diagnostics(CompilationResult result) {
    final runtimeError = widget.controller.error;
    if (runtimeError != null) {
      return _selectable('فشل التنفيذ:\n$runtimeError');
    }
    if (result.diagnostics.isEmpty) {
      return Center(
        child: Text(
          result.success ? 'تمت الترجمة والتنفيذ بنجاح' : 'فشلت الترجمة',
        ),
      );
    }
    return _selectable(
      result.diagnostics
          .map((diagnostic) => '${diagnostic.phase}: ${diagnostic.message}')
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
