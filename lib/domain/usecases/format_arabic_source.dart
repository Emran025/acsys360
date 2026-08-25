String formatArabicSource(String source) {
  if (!_hasBalancedBlocks(source)) return source;
  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
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
  return formatted.join(lineEnding);
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
    if ((inString || inCharacter) &&
        current == '\\' &&
        index + 1 < line.length) {
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
  var inString = false;
  var inCharacter = false;
  final normalized = source.replaceAll('\r\n', '\n');
  for (var index = 0; index < normalized.length; index++) {
    final current = normalized[index];
    if ((inString || inCharacter) &&
        current == '\\' &&
        index + 1 < normalized.length) {
      index++;
      continue;
    }
    if (inString) {
      if (current == '"') inString = false;
      if (current == '\n') return false;
      continue;
    }
    if (inCharacter) {
      if (current == '’') inCharacter = false;
      if (current == '\n') return false;
      continue;
    }
    if (current == '"') {
      inString = true;
      continue;
    }
    if (current == '‘') {
      inCharacter = true;
      continue;
    }
    if (current == '/' &&
        index + 1 < normalized.length &&
        normalized[index + 1] == '/') {
      final lineEnd = normalized.indexOf('\n', index + 2);
      index = lineEnd == -1 ? normalized.length : lineEnd;
      continue;
    }
    if (current == '{') depth++;
    if (current == '}') {
      depth--;
      if (depth < 0) return false;
    }
  }
  return !inString && !inCharacter && depth == 0;
}
