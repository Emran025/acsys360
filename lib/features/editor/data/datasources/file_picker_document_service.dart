import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../domain/services/document_file_service.dart';
import '../../domain/services/source_file_policy.dart';

class FilePickerDocumentService implements DocumentFileService {
  const FilePickerDocumentService();

  @override
  Future<String?> pickSourceFile() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'فتح ملف عربي',
      type: FileType.custom,
      allowedExtensions: [SourceFilePolicy.extension.substring(1)],
    );
    return files.isEmpty ? null : files.first.path;
  }

  @override
  Future<String?> pickWorkspace() =>
      FilePicker.getDirectoryPath(dialogTitle: 'اختر مجلد المشروع');

  @override
  Future<String?> saveSourceFile({
    required String fileName,
    required String text,
  }) async {
    final selected = await FilePicker.saveFile(
      dialogTitle: 'حفظ الملف باسم',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      type: FileType.custom,
      allowedExtensions: [SourceFilePolicy.extension.substring(1)],
    );
    final path = selected?.toFilePath();
    return path == null ? null : const SourceFilePolicy().ensureExtension(path);
  }

  @override
  String baseName(String path) => path.split(Platform.pathSeparator).last;
}
