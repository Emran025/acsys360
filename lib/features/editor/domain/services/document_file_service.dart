abstract interface class DocumentFileService {
  Future<String?> pickSourceFile();
  Future<String?> pickWorkspace();
  Future<String?> saveSourceFile({
    required String fileName,
    required String text,
  });
  String baseName(String path);
}

class UnavailableDocumentFileService implements DocumentFileService {
  const UnavailableDocumentFileService();

  @override
  Future<String?> pickSourceFile() async => null;

  @override
  Future<String?> pickWorkspace() async => null;

  @override
  Future<String?> saveSourceFile({
    required String fileName,
    required String text,
  }) async => null;

  @override
  String baseName(String path) => path.split('/').last;
}
