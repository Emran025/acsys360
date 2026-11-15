import 'dart:io';

import '../../../../core/services/workspace_path_service.dart';

class LocalWorkspacePathService implements WorkspacePathService {
  const LocalWorkspacePathService();

  @override
  String parentOf(String path, {required String fallback}) {
    final separatorIndex = _lastSeparatorIndex(path);
    if (separatorIndex <= 0) return fallback;
    return path.substring(0, separatorIndex);
  }

  @override
  String baseName(String path) {
    var normalized = path;
    while (normalized.isNotEmpty &&
        _isSeparator(normalized.codeUnitAt(normalized.length - 1))) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    final separatorIndex = _lastSeparatorIndex(normalized);
    return separatorIndex < 0
        ? normalized
        : normalized.substring(separatorIndex + 1);
  }

  @override
  String join(String directory, String name) =>
      '$directory${directory.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}$name';

  @override
  bool isSameOrDescendant(String path, String ancestor) {
    final separator = Platform.pathSeparator;
    return path == ancestor || path.startsWith('$ancestor$separator');
  }

  @override
  String relocate(
    String path, {
    required String source,
    required String target,
  }) {
    final separator = Platform.pathSeparator;
    if (path == source) return target;
    if (path.startsWith('$source$separator')) {
      return '$target${path.substring(source.length)}';
    }
    return path;
  }

  int _lastSeparatorIndex(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf(r'\');
    return slash > backslash ? slash : backslash;
  }

  bool _isSeparator(int codeUnit) => codeUnit == 0x2f || codeUnit == 0x5c;
}
