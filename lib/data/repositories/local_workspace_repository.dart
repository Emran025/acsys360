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
    List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      return const [];
    }
    entries.sort((a, b) {
      final aDirectory = a is Directory;
      final bDirectory = b is Directory;
      if (aDirectory != bDirectory) return aDirectory ? -1 : 1;
      return _baseName(
        a.path,
      ).toLowerCase().compareTo(_baseName(b.path).toLowerCase());
    });

    final result = <FileNode>[];
    for (final entry in entries) {
      final name = _baseName(entry.path);
      if (entry is Directory) {
        if (name == '.git') continue;
        result.add(
          FileNode(
            path: entry.path,
            name: name,
            isDirectory: true,
            children: await _readDirectory(entry),
          ),
        );
      } else if (entry is File) {
        result.add(FileNode(path: entry.path, name: name, isDirectory: false));
      }
    }
    return result;
  }

  String _baseName(String path) {
    final separator = Platform.pathSeparator;
    final normalized = path.endsWith(separator)
        ? path.substring(0, path.length - separator.length)
        : path;
    return normalized.split(separator).last;
  }

  String _validateName(String name, String message) {
    final value = name.trim();
    if (value.isEmpty ||
        value.contains('/') ||
        value.contains('\\') ||
        value == '.' ||
        value == '..') {
      throw ArgumentError.value(name, 'name', message);
    }
    return value;
  }

  String _join(String directory, String name) =>
      '${Directory(directory).path}${Platform.pathSeparator}$name';

  @override
  Future<Document> read(String path) async =>
      Document(path: path, text: await File(path).readAsString());

  @override
  Future<Document> create(String rootPath, String name) async {
    final value = _validateName(
      name,
      'اسم الملف يجب أن يكون اسمًا محليًا صالحًا',
    );
    final normalized = value.endsWith(sourceExtension)
        ? value
        : '$value$sourceExtension';
    final file = File(_join(rootPath, normalized));
    await file.create(recursive: true, exclusive: true);
    return Document(path: file.path, text: '');
  }

  @override
  Future<String> createDirectory(String rootPath, String name) async {
    final directory = Directory(
      _join(rootPath, _validateName(name, 'اسم المجلد غير صالح')),
    );
    await directory.create();
    return directory.path;
  }

  @override
  Future<void> write(Document document) =>
      File(document.path).writeAsString(document.text);

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return;
    }
    final directory = Directory(path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> move(String sourcePath, String targetDirectory) async {
    final sourceType = await FileSystemEntity.type(
      sourcePath,
      followLinks: false,
    );
    if (sourceType == FileSystemEntityType.notFound ||
        sourceType == FileSystemEntityType.link) {
      throw StateError('العنصر المصدر غير صالح للنقل');
    }
    final target = Directory(targetDirectory);
    if (!await target.exists()) throw StateError('المجلد الهدف غير موجود');

    final source = FileSystemEntity.typeSync(sourcePath, followLinks: false);
    final sourceAbsolute = File(sourcePath).absolute.path;
    final targetAbsolute = target.absolute.path;
    final separator = Platform.pathSeparator;
    if (sourceType == FileSystemEntityType.directory &&
        (targetAbsolute == sourceAbsolute ||
            targetAbsolute.startsWith('$sourceAbsolute$separator'))) {
      throw StateError('لا يمكن نقل المجلد إلى داخله');
    }

    final targetPath = _join(targetDirectory, _baseName(sourcePath));
    if (await FileSystemEntity.type(targetPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('يوجد عنصر بهذا الاسم في المجلد الهدف');
    }
    if (source == FileSystemEntityType.directory) {
      await Directory(sourcePath).rename(targetPath);
    } else {
      await File(sourcePath).rename(targetPath);
    }
  }

  @override
  Future<void> rename(String path, String newName) async {
    final value = _validateName(newName, 'الاسم الجديد غير صالح');
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound ||
        type == FileSystemEntityType.link) {
      throw StateError('العنصر المطلوب غير موجود');
    }
    final parent = File(path).absolute.parent.path;
    final targetPath = _join(parent, value);
    if (targetPath == File(path).absolute.path) return;
    if (await FileSystemEntity.type(targetPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('يوجد عنصر بهذا الاسم في المجلد نفسه');
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(path).rename(targetPath);
    } else {
      await File(path).rename(targetPath);
    }
  }
}
