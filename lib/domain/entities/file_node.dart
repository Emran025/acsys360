class FileNode {
  final String path;
  final String name;
  final bool isDirectory;
  final List<FileNode> children;

  const FileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.children = const [],
  });
}
