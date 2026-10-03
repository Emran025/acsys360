import 'package:acsys360/features/editor/presentation/ui/widgets/editor_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new file dialog normalizes the submitted name', (tester) async {
    late Future<String?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => result = showNewFileDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  main.arb  ');
    await tester.tap(find.text('إنشاء'));
    await tester.pumpAndSettle();
    expect(await result, 'main.arb');
  });

  testWidgets('discard dialog returns false or true from its actions', (
    tester,
  ) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => result = confirmDiscardDialog(
              context,
              path: '/workspace/main.arb',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text('هل تريد إغلاق «main.arb» دون حفظ التغييرات؟'),
      findsOneWidget,
    );
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });
}
