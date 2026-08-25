import 'package:acsys360/domain/entities/document.dart';
import 'package:acsys360/domain/entities/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document edit, undo, and redo preserve one transaction', () {
    const document = Document(path: 'main.arb', text: 'س = 1;');
    final edited = document.edit(
      const TextEdit(offset: 4, before: '1', after: '2'),
    );

    expect(edited.text, 'س = 2;');
    expect(edited.isDirty, isTrue);
    expect(edited.undo().text, document.text);
    expect(edited.undo().redo().text, edited.text);
  });

  test('rejects stale or out-of-range edits', () {
    const document = Document(path: 'main.arb', text: 'س = 1;');

    expect(
      () => document.edit(const TextEdit(offset: 99, before: '', after: 'س')),
      throwsRangeError,
    );
    expect(
      () => document.edit(const TextEdit(offset: 0, before: 'ص', after: 'س')),
      throwsStateError,
    );
  });

  test('workspace opens a path once and keeps active index valid on close', () {
    const first = Document(path: 'first.arb', text: '');
    const second = Document(path: 'second.arb', text: '');
    var workspace = const Workspace(rootPath: '/workspace');

    workspace = workspace.open(first).open(second).open(first);
    expect(workspace.documents.map((document) => document.path), [
      'first.arb',
      'second.arb',
    ]);
    expect(workspace.activeIndex, 0);

    workspace = workspace.close(0);
    expect(workspace.activeDocument?.path, 'second.arb');
    expect(workspace.activeIndex, 0);
    expect(workspace.close(0).activeIndex, -1);
  });
}
