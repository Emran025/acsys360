import '../entities/document.dart';

abstract interface class WorkspaceRepository {
  Future<List<String>> listFiles(String rootPath);
  Future<Document> read(String path);
  Future<void> write(Document document);
}

abstract interface class CompilerRepository {
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required List<Document> documents,
  });
}
