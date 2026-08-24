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

  final workspace = Workspace(rootPath: '.').open(original);
  assert(workspace.activeDocument?.path == 'main.arb');
  assert(workspace.closeActive().activeDocument == null);
  print('Domain self-tests passed');
}
