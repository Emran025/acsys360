import 'package:compiler_contracts/compiler_contracts.dart';

import '../entities/document.dart';
import '../entities/file_node.dart';

abstract interface class WorkspaceRepository {
  Future<List<String>> listFiles(String rootPath);
  Future<List<FileNode>> listTree(String rootPath);
  Future<Document> read(String path);
  Future<Document> create(String rootPath, String name);
  Future<String> createDirectory(String rootPath, String name);
  Future<void> write(Document document);
  Future<void> delete(String path);
  Future<void> move(String sourcePath, String targetDirectory);
  Future<void> rename(String path, String newName);
}

abstract interface class CompilerRepository {
  Future<Map<String, dynamic>> compile({
    required String rootPath,
    required String sourcePath,
    required List<Document> documents,
    String target = 'none',
    String? artifactDirectory,
    CompilationMode? mode,
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
