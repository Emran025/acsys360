import 'dart:io';

import '../../domain/entities/document.dart';
import '../../domain/entities/file_node.dart';
import '../../domain/repositories/workspace_repository.dart';

class LocalWorkspaceRepository implements WorkspaceRepository {
  static const sourceExtension = '.arb';

  @override
  Future<List<String>> listFiles(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return const [];
    return root
        .list(recursive: true, followLinks: false)
        .where(
          (entity) => entity is File && entity.path.endsWith(sourceExtension),
        )
        .map((entity) => entity.path)
        .toList();
  }

  @override
  Future<List<FileNode>> listTree(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) return const [];
    return _readDirectory(root);
  }

  Future<List<FileNode>> _readDirectory(Directory directory) async {
    final entries = await directory.list(followLinks: false).toList();
    entries.sort((a, b) {
      final aDirectory = a is Directory;
      final bDirectory = b is Directory;
      if (aDirectory != bDirectory) return aDirectory ? -1 : 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    final result = <FileNode>[];
    for (final entry in entries) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      if (entry is Directory) {
        final children = await _readDirectory(entry);
        if (children.isNotEmpty) {
          result.add(
            FileNode(
              path: entry.path,
              name: name,
              isDirectory: true,
              children: children,
            ),
          );
        }
      } else if (entry is File && entry.path.endsWith(sourceExtension)) {
        result.add(FileNode(path: entry.path, name: name, isDirectory: false));
      }
    }
    return result;
  }

  @override
  Future<Document> read(String path) async =>
      Document(path: path, text: await File(path).readAsString());

  @override
  Future<Document> create(String rootPath, String name) async {
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name == '.' ||
        name == '..') {
      throw ArgumentError.value(
        name,
        'name',
        'اسم الملف يجب أن يكون اسمًا محليًا صالحًا',
      );
    }
    final normalized = name.endsWith(sourceExtension)
        ? name
        : '$name$sourceExtension';
    final file = File(
      '${Directory(rootPath).path}${Platform.pathSeparator}$normalized',
    );
    await file.create(recursive: true, exclusive: true);
    return Document(path: file.path, text: '');
  }

  @override
  Future<void> write(Document document) =>
      File(document.path).writeAsString(document.text);
}
