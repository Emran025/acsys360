import 'dart:convert';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    1 => _codeBlock(
      title: 'Tokens',
      language: 'JSON',
      source: prettyJson(result.tokens),
    ),
    2 =>
      result.syntaxTree == null
          ? _selectable('لا توجد شجرة تحليل')
          : _syntaxTree(result.syntaxTree!),
    3 => _symbolTable(result.symbols),
    4 => _codeBlock(
      title: 'Semantic',
      language: 'JSON',
      source: prettyJson(
        result.diagnostics
            .where((item) => item.phase == 'semantic')
            .map((item) => item.toJson())
            .toList(),
      ),
    ),
    5 => _threeAddressCode(result.threeAddressCode),
    6 =>
      result.intermediateRepresentation == null
          ? _selectable('لا يوجد Typed IR')
          : _typedIr(result.intermediateRepresentation!),
    7 =>
      result.assembly.isEmpty
          ? _selectable('لا يوجد مخرج Assembly')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: _codeBlock(
                title: 'تعليمات Assembly',
                language: 'Assembly',
                source: result.assembly,
              ),
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

  Widget _syntaxTree(Map<String, Object?> syntaxTree) {
    final rows = <_SyntaxTreeRow>[];
    _collectSyntaxTreeRows(syntaxTree, rows);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('عرض الشجرة', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 56,
              columnSpacing: 20,
              border: _tableBorder(context),
              headingRowColor: _tableHeaderColor(context),
              headingTextStyle: _tableHeaderTextStyle(context),
              columns: const [
                DataColumn(label: Text('العقدة')),
                DataColumn(label: Text('المستوى')),
                DataColumn(label: Text('البيانات')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: row.depth * 16,
                          ),
                          child: Text(
                            row.label,
                            style: TextStyle(
                              fontWeight: row.depth == 0
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text('${row.depth}')),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(
                            row.details,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _codeBlock(
            title: 'الشجرة الأصلية (JSON)',
            language: 'JSON',
            source: prettyJson(syntaxTree),
          ),
        ],
      ),
    );
  }

  Widget _symbolTable(List<SymbolRecord> symbols) {
    if (symbols.isEmpty) return _selectable('لا توجد رموز في جدول الرموز');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('جدول الرموز', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 56,
              columnSpacing: 20,
              border: _tableBorder(context),
              headingRowColor: _tableHeaderColor(context),
              headingTextStyle: _tableHeaderTextStyle(context),
              columns: const [
                DataColumn(label: Text('الاسم')),
                DataColumn(label: Text('الصنف')),
                DataColumn(label: Text('النوع')),
                DataColumn(label: Text('الملف')),
                DataColumn(label: Text('السطر')),
                DataColumn(label: Text('العمود')),
              ],
              rows: [
                for (final symbol in symbols)
                  DataRow(
                    cells: [
                      DataCell(Text(symbol.name)),
                      DataCell(Text(symbol.kind)),
                      DataCell(Text(symbol.type)),
                      DataCell(
                        Tooltip(
                          message: symbol.span.sourcePath,
                          child: Text(
                            symbol.span.sourcePath.split(RegExp(r'[\\/]')).last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('${symbol.span.line}')),
                      DataCell(Text('${symbol.span.column}')),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _codeBlock(
            title: 'البيانات الأصلية (JSON)',
            language: 'JSON',
            source: prettyJson([for (final symbol in symbols) symbol.toJson()]),
          ),
        ],
      ),
    );
  }

  Widget _threeAddressCode(List<String> instructions) {
    if (instructions.isEmpty) {
      return _selectable('لا يوجد Three Address Code');
    }
    final rows = [
      for (var index = 0; index < instructions.length; index++)
        _TacRow.parse(index + 1, instructions[index]),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('جدول 3AC', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 56,
              columnSpacing: 20,
              border: _tableBorder(context),
              headingRowColor: _tableHeaderColor(context),
              headingTextStyle: _tableHeaderTextStyle(context),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('op')),
                DataColumn(label: Text('arg1')),
                DataColumn(label: Text('arg2')),
                DataColumn(label: Text('result')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text('${row.number}')),
                      DataCell(Text(row.operation)),
                      DataCell(Text(row.argument1)),
                      DataCell(Text(row.argument2)),
                      DataCell(Text(row.result)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _codeBlock(
            title: 'التعليمات الأصلية',
            language: '3AC',
            source: instructions.join('\n'),
          ),
        ],
      ),
    );
  }

  Widget _typedIr(Map<String, Object?> intermediateRepresentation) {
    final rows = <_IrRow>[];
    for (final entry in intermediateRepresentation.entries) {
      if (entry.key == 'types' && entry.value is List) {
        final types = entry.value as List;
        for (var index = 0; index < types.length; index++) {
          rows.add(_IrRow('الأنواع', '[$index]', '${types[index]}', ''));
        }
      } else if (entry.key == 'symbols' || entry.key == 'blocks') {
        final section = entry.key == 'symbols' ? 'الرموز' : 'الكتل';
        final items = _irMaps(entry.value);
        for (var index = 0; index < items.length; index++) {
          final item = items[index];
          final name = item['name']?.toString() ?? '[$index]';
          final primaryValue = entry.key == 'symbols'
              ? item['type']?.toString() ?? ''
              : item['statementCount']?.toString() ?? '';
          final details = item.entries
              .where(
                (field) =>
                    field.key != 'name' &&
                    field.key !=
                        (entry.key == 'symbols' ? 'type' : 'statementCount'),
              )
              .map((field) => '${field.key}: ${field.value ?? 'null'}')
              .join('، ');
          rows.add(_IrRow(section, name, primaryValue, details));
        }
      } else {
        rows.add(
          _IrRow(
            'البيانات',
            entry.key,
            entry.value is Map || entry.value is List
                ? prettyJson(entry.value)
                : entry.value?.toString() ?? 'null',
            '',
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('جدول Typed IR', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 56,
              columnSpacing: 20,
              border: _tableBorder(context),
              headingRowColor: _tableHeaderColor(context),
              headingTextStyle: _tableHeaderTextStyle(context),
              columns: const [
                DataColumn(label: Text('القسم')),
                DataColumn(label: Text('الاسم / الحقل')),
                DataColumn(label: Text('النوع / القيمة')),
                DataColumn(label: Text('تفاصيل')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.section)),
                      DataCell(Text(row.name)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            row.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            row.details,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _codeBlock(
            title: 'البيانات الأصلية (JSON)',
            language: 'JSON',
            source: prettyJson(intermediateRepresentation),
          ),
        ],
      ),
    );
  }

  Widget _codeBlock({
    required String title,
    required String language,
    required String source,
  }) => _SelectableCodeBlock(
    title: title,
    language: language,
    source: source,
    onCopy: () => _copyCode(source),
  );

  TableBorder _tableBorder(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return TableBorder.all(color: color, width: 1);
  }

  WidgetStateProperty<Color?> _tableHeaderColor(BuildContext context) =>
      WidgetStatePropertyAll(
        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .6),
      );

  TextStyle? _tableHeaderTextStyle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.w700,
    );
  }

  Future<void> _copyCode(String source) async {
    try {
      await Clipboard.setData(ClipboardData(text: source));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم نسخ المحتوى')));
    } on Object catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر نسخ المحتوى: $exception')));
    }
  }

  List<Map<String, Object?>> _irMaps(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) Map<String, Object?>.from(item),
    ];
  }

  void _collectSyntaxTreeRows(
    Object? value,
    List<_SyntaxTreeRow> rows, {
    int depth = 0,
    String relation = 'الجذر',
  }) {
    if (value is Map) {
      final node = Map<String, Object?>.from(value);
      final kind = node['kind']?.toString();
      final name = node['name']?.toString();
      final label = [
        if (relation != 'الجذر') relation,
        if (kind != null && kind.isNotEmpty) kind,
        if ((kind == null || kind.isEmpty) && name != null && name.isNotEmpty)
          name,
      ].join(' · ');
      final details = node.entries
          .where(
            (entry) =>
                entry.key != 'kind' &&
                entry.value is! Map &&
                entry.value is! List,
          )
          .map((entry) => '${entry.key}: ${entry.value ?? 'null'}')
          .join('، ');
      rows.add(_SyntaxTreeRow(label: label, depth: depth, details: details));
      for (final entry in node.entries) {
        if (entry.value is Map || entry.value is List) {
          _collectSyntaxTreeRows(
            entry.value,
            rows,
            depth: depth + 1,
            relation: entry.key,
          );
        }
      }
      return;
    }
    if (value is List) {
      for (var index = 0; index < value.length; index++) {
        _collectSyntaxTreeRows(
          value[index],
          rows,
          depth: depth,
          relation: '$relation[$index]',
        );
      }
      return;
    }
    rows.add(
      _SyntaxTreeRow(
        label: relation,
        depth: depth,
        details: value?.toString() ?? 'null',
      ),
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
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SelectableText(
        value.isEmpty ? 'لا توجد بيانات لهذه المرحلة' : value,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      ),
    ),
  );
}

class _SyntaxTreeRow {
  final String label;
  final int depth;
  final String details;

  const _SyntaxTreeRow({
    required this.label,
    required this.depth,
    required this.details,
  });
}

class _SelectableCodeBlock extends StatelessWidget {
  final String title;
  final String language;
  final String source;
  final VoidCallback onCopy;

  const _SelectableCodeBlock({
    required this.title,
    required this.language,
    required this.source,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colors.surfaceContainerHighest,
            padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    language,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'نسخ',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          LayoutBuilder(
            builder: (context, constraints) => Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth - 24,
                  ),
                  child: SelectableText.rich(
                    TextSpan(
                      style: TextStyle(
                        color: colors.onSurface,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                      children: _highlightCode(source, language, colors),
                    ),
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _highlightCode(
    String source,
    String language,
    ColorScheme colors,
  ) {
    final spans = <InlineSpan>[];
    final pattern = switch (language) {
      'JSON' => RegExp(
        r'"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\],:]',
      ),
      'Assembly' => RegExp(
        r'^\s*[A-Za-z_][A-Za-z_0-9]*|\b(?:section|global|extern|mov|lea|push|pop|call|ret|syscall|cmp|test|jmp|je|jne|jz|jnz|add|sub|imul|idiv|xor|and|or|db|dq|resb|resq|rax|rbx|rcx|rdx|rsi|rdi|rsp|rbp|eax|ebx|ecx|edx)\b',
        caseSensitive: false,
        multiLine: true,
      ),
      _ => RegExp(r'^[A-Za-z_][A-Za-z_0-9]*|\b(?:LABEL|JUMP|BRANCH|ALLOC)\b'),
    };
    var offset = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: source.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      Color? color;
      if (language == 'JSON') {
        if (token.startsWith('"')) {
          final after = source.substring(match.end).trimLeft();
          color = after.startsWith(':') ? colors.primary : colors.secondary;
        } else if (RegExp(r'^-?\d').hasMatch(token)) {
          color = colors.tertiary;
        } else if (token == 'true' || token == 'false' || token == 'null') {
          color = colors.error;
        } else {
          color = colors.outline;
        }
      } else {
        color = colors.primary;
      }
      spans.add(
        TextSpan(
          text: token,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      );
      offset = match.end;
    }
    if (offset < source.length) {
      spans.add(TextSpan(text: source.substring(offset)));
    }
    return spans;
  }
}

class _IrRow {
  final String section;
  final String name;
  final String value;
  final String details;

  const _IrRow(this.section, this.name, this.value, this.details);
}

class _TacRow {
  final int number;
  final String operation;
  final String argument1;
  final String argument2;
  final String result;

  const _TacRow({
    required this.number,
    required this.operation,
    required this.argument1,
    required this.argument2,
    required this.result,
  });

  factory _TacRow.parse(int number, String instruction) {
    final parsed = _TacInstruction.parse(instruction);
    return _TacRow(
      number: number,
      operation: parsed.operation,
      argument1: parsed.argument1,
      argument2: parsed.argument2,
      result: parsed.result,
    );
  }
}

class _TacInstruction {
  final String operation;
  final String argument1;
  final String argument2;
  final String result;

  const _TacInstruction(
    this.operation, {
    this.argument1 = '',
    this.argument2 = '',
    this.result = '',
  });

  factory _TacInstruction.parse(String instruction) {
    final assignment = RegExp(r'^(.+?)\s*=\s*(.+)$').firstMatch(instruction);
    if (assignment != null) {
      final target = assignment.group(1)!.trim();
      final expression = assignment.group(2)!.trim();
      final binary = RegExp(
        r'^(.+?)\s+([^\s]+)\s+(.+)$',
      ).firstMatch(expression);
      if (binary != null) {
        return _TacInstruction(
          binary.group(2)!.trim(),
          argument1: binary.group(1)!.trim(),
          argument2: binary.group(3)!.trim(),
          result: target,
        );
      }
      final unary = RegExp(r'^([+\-!~])\s*(.+)$').firstMatch(expression);
      if (unary != null) {
        return _TacInstruction(
          unary.group(1)!.trim(),
          argument1: unary.group(2)!.trim(),
          result: target,
        );
      }
      return _TacInstruction('=', argument1: expression, result: target);
    }

    final parts = instruction.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return const _TacInstruction('');
    final operation = parts.first;
    final operands = instruction.trim().substring(operation.length).trim();
    final values = operands.isEmpty
        ? const <String>[]
        : operands.split(RegExp(r',\s*'));
    switch (operation) {
      case 'ALLOC':
        final allocation = operands.split(RegExp(r',\s*'));
        return _TacInstruction(
          operation,
          argument1: allocation.length > 1 ? allocation[1] : '',
          result: allocation.first,
        );
      case 'PRINT':
      case 'PARAM':
        return _TacInstruction(operation.toLowerCase(), argument1: operands);
      case 'READ':
        return _TacInstruction(operation.toLowerCase(), result: operands);
      case 'CALL':
        return _TacInstruction(
          operation.toLowerCase(),
          argument1: values.length > 1 ? values[1] : '',
          result: values.isNotEmpty ? values.first : '',
        );
      case 'BRANCH':
        return _TacInstruction(
          operation.toLowerCase(),
          argument1: values.isNotEmpty ? values[0] : '',
          argument2: values.length > 1 ? values[1] : '',
          result: values.length > 2 ? values[2] : '',
        );
      case 'LABEL':
      case 'JUMP':
        return _TacInstruction(operation.toLowerCase(), result: operands);
      default:
        return _TacInstruction(
          operation.toLowerCase(),
          argument1: values.isNotEmpty ? values[0] : operands,
          argument2: values.length > 1 ? values[1] : '',
          result: values.length > 2 ? values[2] : '',
        );
    }
  }
}

String prettyJson(Object? value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return '$value';
  }
}
