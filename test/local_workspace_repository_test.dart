import 'dart:io';

import 'package:acsys360/features/editor/data/repositories_impl/local_workspace_repository_impl.dart';
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
      final separator = Platform.pathSeparator;
      final source = Directory('${root.path}${separator}source');
      final target = Directory('${root.path}${separator}target');
      final child = Directory('${source.path}${separator}child');
      await child.create(recursive: true);
      await target.create();

      final repository = LocalWorkspaceRepository();
      await repository.move(source.path, target.path);
      expect(
        await Directory(
          '${target.path}${separator}source${separator}child',
        ).exists(),
        isTrue,
      );

      final nestedTarget = Directory(
        '${target.path}${separator}source${separator}nested',
      );
      await nestedTarget.create();
      expect(
        () => repository.move(
          '${target.path}${separator}source',
          nestedTarget.path,
        ),
        throwsStateError,
      );
    },
  );

  test('renames a file without overwriting an existing entry', () async {
    final root = await Directory.systemTemp.createTemp('acsys360-rename-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/main.arb');
    await file.writeAsString('برنامج اختبار؛ {}.');

    final repository = LocalWorkspaceRepository();
    await repository.rename(file.path, 'renamed.arb');

    expect(await File('${root.path}/renamed.arb').exists(), isTrue);
    expect(await file.exists(), isFalse);
  });

  test('rejects path traversal in file and directory names', () async {
    final root = await Directory.systemTemp.createTemp('acsys360-traversal-');
    addTearDown(() => root.delete(recursive: true));
    final repository = LocalWorkspaceRepository();

    expect(
      () => repository.create(root.path, '../outside'),
      throwsArgumentError,
    );
    expect(
      () => repository.createDirectory(root.path, '..\\outside'),
      throwsArgumentError,
    );
    expect(await File('${root.parent.path}/outside.arb').exists(), isFalse);
  });

  test(
    'does not follow symlinks while listing or moving workspace entries',
    () async {
      if (Platform.isWindows) return;
      final root = await Directory.systemTemp.createTemp('acsys360-symlink-');
      addTearDown(() => root.delete(recursive: true));
      final outside = await Directory.systemTemp.createTemp(
        'acsys360-symlink-target-',
      );
      addTearDown(() => outside.delete(recursive: true));
      await File('${outside.path}/secret.arb').writeAsString('secret');
      final link = Link('${root.path}/linked');
      await link.create(outside.path);

      final repository = LocalWorkspaceRepository();
      final tree = await repository.listTree(root.path);
      expect(tree.where((node) => node.name == 'linked'), isEmpty);
      expect(() => repository.move(link.path, root.path), throwsStateError);
      expect(() => repository.rename(link.path, 'renamed'), throwsStateError);
    },
  );
}
