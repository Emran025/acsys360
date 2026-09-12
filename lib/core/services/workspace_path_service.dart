abstract interface class WorkspacePathService {
  String parentOf(String path, {required String fallback});

  String baseName(String path);

  String join(String directory, String name);

  bool isSameOrDescendant(String path, String ancestor);

  String relocate(
    String path, {
    required String source,
    required String target,
  });
}

/// Default path policy for domain tests; production injects the platform adapter.
class DefaultWorkspacePathService implements WorkspacePathService {
  const DefaultWorkspacePathService();

  String _separator(String path) => path.contains('\\') ? '\\' : '/';

  @override
  String parentOf(String path, {required String fallback}) {
    final separator = _separator(path);
    final index = path.lastIndexOf(separator);
    if (index <= 0) return fallback;
    return path.substring(0, index);
  }

  @override
  String baseName(String path) {
    final separator = _separator(path);
    final normalized = path.endsWith(separator)
        ? path.substring(0, path.length - separator.length)
        : path;
    return normalized.split(separator).last;
  }

  @override
  String join(String directory, String name) {
    final separator = _separator(directory);
    return '$directory${directory.endsWith(separator) ? '' : separator}$name';
  }

  @override
  bool isSameOrDescendant(String path, String ancestor) {
    final separator = _separator(ancestor);
    return path == ancestor || path.startsWith('$ancestor$separator');
  }

  @override
  String relocate(
    String path, {
    required String source,
    required String target,
  }) {
    final separator = _separator(source);
    if (path == source) return target;
    if (path.startsWith('$source$separator')) {
      return '$target${path.substring(source.length)}';
    }
    return path;
  }
}
