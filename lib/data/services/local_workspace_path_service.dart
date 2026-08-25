import 'dart:io';

import '../../domain/services/workspace_path_service.dart';

class LocalWorkspacePathService implements WorkspacePathService {
  const LocalWorkspacePathService();

  @override
  String parentOf(String path, {required String fallback}) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    if (separatorIndex <= 0) return fallback;
    return path.substring(0, separatorIndex);
  }

  @override
  String baseName(String path) {
    final separator = Platform.pathSeparator;
    final normalized = path.endsWith(separator)
        ? path.substring(0, path.length - separator.length)
        : path;
    return normalized.split(separator).last;
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
}
