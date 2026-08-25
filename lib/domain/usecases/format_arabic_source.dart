String formatArabicSource(String source) {
  if (!_hasBalancedBlocks(source)) return source;
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  var depth = 0;
  final formatted = <String>[];
  for (final rawLine in lines) {
    final trimmedRight = rawLine.trimRight();
    if (trimmedRight.trim().isEmpty) {
      formatted.add('');
      continue;
    }
    final content = trimmedRight.trimLeft();
    final leadingClosures = _leadingClosingBraces(content);
    depth = (depth - leadingClosures).clamp(0, depth);
    formatted.add('${List.filled(depth, '  ').join()}$content');
    final balance = _braceBalance(content) + leadingClosures;
    depth = (depth + balance).clamp(0, 1 << 20);
  }
  return formatted.join('\n');
}

int _leadingClosingBraces(String line) {
  var index = 0;
  while (index < line.length && line[index] == '}') {
    index++;
  }
  return index;
}

int _braceBalance(String line) {
  var balance = 0;
  var inString = false;
  var inCharacter = false;
  for (var index = 0; index < line.length; index++) {
    final current = line[index];
    if (inString && current == '\\' && index + 1 < line.length) {
      index++;
      continue;
    }
    if (!inCharacter && current == '"') {
      inString = !inString;
      continue;
    }
    if (!inString && !inCharacter && current == '‘') {
      inCharacter = true;
      continue;
    }
    if (!inString && inCharacter && current == '’') {
      inCharacter = false;
      continue;
    }
    if (inString || inCharacter) continue;
    if (current == '/' && index + 1 < line.length && line[index + 1] == '/') {
      break;
    }
    if (current == '{') balance++;
    if (current == '}') balance--;
  }
  return balance;
}

bool _hasBalancedBlocks(String source) {
  var depth = 0;
  for (final line in source.replaceAll('\r\n', '\n').split('\n')) {
    depth += _braceBalance(line);
    if (depth < 0) return false;
  }
  return depth == 0;
}
