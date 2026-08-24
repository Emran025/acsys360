String formatArabicSource(String source) {
  if (!_hasBalancedBlocks(source)) return source;
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  var depth = 0;
  final formatted = <String>[];
  for (final rawLine in lines) {
    final content = rawLine.trimRight();
    if (content.trim().isEmpty) {
      formatted.add('');
      continue;
    }
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('}')) depth = (depth - 1).clamp(0, depth);
    formatted.add('${List.filled(depth, '  ').join()}$trimmed');
    if (trimmed.endsWith('{')) depth++;
  }
  return formatted.join('\n');
}

bool _hasBalancedBlocks(String source) {
  var depth = 0;
  for (final character in source.split('')) {
    if (character == '{') depth++;
    if (character == '}') {
      depth--;
      if (depth < 0) return false;
    }
  }
  return depth == 0;
}
