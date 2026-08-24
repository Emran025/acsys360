import 'package:compiler_contracts/compiler_contracts.dart';

import '../entities/document.dart';
import '../entities/file_node.dart';

abstract interface class WorkspaceRepository {
  Future<List<String>> listFiles(String rootPath);
  Future<List<FileNode>> listTree(String rootPath);
  Future<Document> read(String path);
  Future<Document> create(String rootPath, String name);
  Future<void> write(Document document);
}

abstract interface class CompilerRepository {
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
  });
}

abstract interface class AssistRepository {
  Future<AssistResponse> complete({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
    List<String> symbols,
  });

  Future<AssistResponse> help({
    required String rootPath,
    required String sourcePath,
    required String sourceText,
    required int offset,
  });
}
