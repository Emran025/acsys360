import 'package:acsys360/features/editor/domain/entities/editor_diagnostic.dart';
import 'package:acsys360/features/editor/presentation/ui/widgets/diagnostic_popover_widget.dart';
import 'package:acsys360/features/editor/presentation/ui/widgets/help_popover_widget.dart';
import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('diagnostic popover renders actions and invokes callbacks', (
    tester,
  ) async {
    var applied = false;
    var closed = false;
    const diagnostic = EditorDiagnostic(
      severity: EditorDiagnosticSeverity.error,
      phase: 'syntax',
      code: 'S001',
      message: 'متوقع فاصلة منقوطة',
      sourcePath: 'main.arb',
      offset: 0,
      length: 1,
      line: 1,
      column: 1,
      actions: [
        EditorCodeAction(
          title: 'إضافة فاصلة',
          offset: 0,
          length: 0,
          replacement: ';',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticPopoverWidget(
            diagnostic: diagnostic,
            onApply: (_) => applied = true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    expect(find.text('S001 · syntax'), findsOneWidget);
    expect(find.text('إضافة فاصلة'), findsOneWidget);
    await tester.tap(find.text('إضافة فاصلة'));
    await tester.tap(find.byTooltip('إغلاق التشخيص'));
    expect(applied, isTrue);
    expect(closed, isTrue);
  });

  testWidgets('help popover renders help content and closes', (tester) async {
    var closed = false;
    const help = AssistHelp(
      keyword: 'إذا',
      title: 'شرط',
      description: 'ينفذ كتلة عند تحقق الشرط.',
      syntax: 'إذا <شرط> افعل',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HelpPopoverWidget(help: help, onClose: () => closed = true),
        ),
      ),
    );
    expect(find.text('إذا · شرط'), findsOneWidget);
    expect(find.text('الصيغة: إذا <شرط> افعل'), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق المساعدة'));
    expect(closed, isTrue);
  });
}
