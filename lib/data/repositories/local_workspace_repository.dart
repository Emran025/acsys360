import 'dart:io';

import '../../domain/entities/document.dart';
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
  Future<Document> read(String path) async =>
      Document(path: path, text: await File(path).readAsString());

  @override
  Future<void> write(Document document) =>
      File(document.path).writeAsString(document.text);
}
