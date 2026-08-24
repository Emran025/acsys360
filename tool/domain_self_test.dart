import '../lib/domain/entities/document.dart';
import '../lib/domain/entities/workspace.dart';

void main() {
  final original = Document(path: 'main.arb', text: 'abc');
  final edited = original.edit(
    const TextEdit(offset: 1, before: 'b', after: 'XYZ'),
  );
  assert(edited.text == 'aXYZc');
  assert(edited.isDirty);
  assert(edited.undo().text == 'abc');
  assert(edited.undo().redo().text == 'aXYZc');
  final branched = edited.undo().edit(
    const TextEdit(offset: 1, before: 'b', after: 'Q'),
  );
  assert(branched.redo().text == branched.text);

  final second = const Document(path: 'second.arb', text: 'second');
  final workspace = Workspace(rootPath: '.')
      .open(original)
      .replaceActive(edited)
      .open(second);
  assert(workspace.activeDocument?.path == 'second.arb');
  assert(workspace.select(0).activeDocument?.text == 'aXYZc');
  assert(workspace.closeActive().activeDocument?.path == 'main.arb');
  print('Domain self-tests passed');
}
