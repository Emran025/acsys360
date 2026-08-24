import 'dart:io';

import 'package:acsys360/data/repositories/local_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a sorted source tree and omits unsupported entries', () async {
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

    expect(tree.map((node) => node.name), ['src', 'root.arb']);
    expect(tree.first.isDirectory, isTrue);
    expect(tree.first.children.map((node) => node.name), ['a.arb', 'z.arb']);
    expect(tree.first.children.every((node) => !node.isDirectory), isTrue);
  });
}
