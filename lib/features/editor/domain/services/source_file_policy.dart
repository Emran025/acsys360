class SourceFilePolicy {
  static const extension = '.arb';

  const SourceFilePolicy();

  bool accepts(String path) => path.toLowerCase().endsWith(extension);

  String ensureExtension(String path) =>
      accepts(path) ? path : '$path$extension';
}
