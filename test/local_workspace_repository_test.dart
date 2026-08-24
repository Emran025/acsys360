import 'dart:io';

import 'package:acsys360/data/repositories/local_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a sorted tree of visible workspace entries', () async {
    final root = await Directory.systemTemp.createTemp('acsys360-tree-');
    addTearDown(() => root.delete(recursive: true));

    await Directory('${root.path}/src').create(recursive: true);
    await Directory('${root.path}/empty').create();
    await Directory('${root.path}/.hidden').create();
    await File('${root.path}/src/z.arb').writeAsString('');
    await File('${root.path}/src/a.arb').writeAsString('');
    await File('${root.path}/src/readme.txt').writeAsString('');
    await File('${root.path}/root.arb').writeAsString('');
    await File('${root.path}/.hidden/secret.arb').writeAsString('');

    final tree = await LocalWorkspaceRepository().listTree(root.path);

    expect(tree.map((node) => node.name), [
      '.hidden',
      'empty',
      'src',
      'root.arb',
    ]);
    expect(tree[0].children.single.name, 'secret.arb');
    expect(tree[1].children, isEmpty);
    expect(tree[2].children.map((node) => node.name), [
      'a.arb',
      'readme.txt',
      'z.arb',
    ]);
  });

  test(
    'moves directories and rejects moving a directory into itself',
    () async {
      final root = await Directory.systemTemp.createTemp('acsys360-move-');
      addTearDown(() => root.delete(recursive: true));
      final source = Directory('${root.path}/source');
      final target = Directory('${root.path}/target');
      final child = Directory('${source.path}/child');
      await child.create(recursive: true);
      await target.create();

      final repository = LocalWorkspaceRepository();
      await repository.move(source.path, target.path);
      expect(await Directory('${target.path}/source/child').exists(), isTrue);

      final nestedTarget = Directory('${target.path}/source/nested');
      await nestedTarget.create();
      expect(
        () => repository.move('${target.path}/source', nestedTarget.path),
        throwsStateError,
      );
    },
  );

  test('renames a file without overwriting an existing entry', () async {
    final root = await Directory.systemTemp.createTemp('acsys360-rename-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/main.arb');
    await file.writeAsString('برنامج اختبار {}.');

    final repository = LocalWorkspaceRepository();
    await repository.rename(file.path, 'renamed.arb');

    expect(await File('${root.path}/renamed.arb').exists(), isTrue);
    expect(await file.exists(), isFalse);
  });
}
