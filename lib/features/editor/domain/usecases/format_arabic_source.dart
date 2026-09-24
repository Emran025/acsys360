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
  String? characterCloser;
  for (var index = 0; index < line.length; index++) {
    final current = line[index];
    if (characterCloser != null) {
      if (current == '\\' && index + 1 < line.length) {
        index++;
      } else if (current == characterCloser) {
        characterCloser = null;
      }
      continue;
    }
    if (inString) {
      if (current == '\\' && index + 1 < line.length) index++;
      if (current == '"') inString = false;
      continue;
    }
    if (current == '"') {
      inString = true;
    } else if (current == '‘' || current == '’' || current == '\'') {
      characterCloser = current == '‘' ? '’' : '‘';
    } else if (current == '/' &&
        index + 1 < line.length &&
        line[index + 1] == '/') {
      break;
    } else if (current == '{') {
      balance++;
    } else if (current == '}') {
      balance--;
    }
  }
  return balance;
}

bool _hasBalancedBlocks(String source) {
  var depth = 0;
  var inString = false;
  String? characterCloser;
  final normalized = source.replaceAll('\r\n', '\n');
  for (var index = 0; index < normalized.length; index++) {
    final current = normalized[index];
    if (characterCloser != null) {
      if (current == '\\' && index + 1 < normalized.length) {
        index++;
      } else if (current == characterCloser) {
        characterCloser = null;
      } else if (current == '\n') {
        return false;
      }
      continue;
    }
    if (inString) {
      if (current == '\\' && index + 1 < normalized.length) index++;
      if (current == '"') inString = false;
      if (current == '\n') return false;
      continue;
    }
    if (current == '"') {
      inString = true;
    } else if (current == '‘' || current == '’' || current == '\'') {
      characterCloser = current == '‘' ? '’' : '‘';
    } else if (current == '/' &&
        index + 1 < normalized.length &&
        normalized[index + 1] == '/') {
      final lineEnd = normalized.indexOf('\n', index + 2);
      index = lineEnd == -1 ? normalized.length : lineEnd;
    } else if (current == '{') {
      depth++;
    } else if (current == '}') {
      depth--;
      if (depth < 0) return false;
    }
  }
  return !inString && characterCloser == null && depth == 0;
}
