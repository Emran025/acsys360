class LineCommentEdit {
  final int offset;
  final String before;
  final String after;
  final int selectionBase;
  final int selectionExtent;

  const LineCommentEdit({
    required this.offset,
    required this.before,
    required this.after,
    required this.selectionBase,
    required this.selectionExtent,
  });
}

/// ينفذ أمر التعليق السطري الوحيد في grammar: `//`، كتعديل واحد قابل للتراجع.
class ToggleLineComment {
  const ToggleLineComment();

  LineCommentEdit apply(String text, int selectionBase, int selectionExtent) {
    final base = selectionBase.clamp(0, text.length).toInt();
    final extent = selectionExtent.clamp(0, text.length).toInt();
    final selectionStart = base <= extent ? base : extent;
    final selectionEnd = base <= extent ? extent : base;
    final firstLineStart = selectionStart == 0
        ? 0
        : text.lastIndexOf('\n', selectionStart - 1) + 1;
    final lastLineEndIndex = text.indexOf('\n', selectionEnd);
    final lastLineEnd = lastLineEndIndex == -1 ? text.length : lastLineEndIndex;
    final before = text.substring(firstLineStart, lastLineEnd);
    final lines = before.split('\n');
    final nonEmpty = lines.where((line) => line.trim().isNotEmpty).toList();
    final uncomment =
        nonEmpty.isNotEmpty &&
        nonEmpty.every((line) => line.trimLeft().startsWith('//'));
    final transformedLines = lines.map((line) {
      if (line.trim().isEmpty) return line;
      final indent = RegExp(r'^[ \t]*').stringMatch(line) ?? '';
      final content = line.substring(indent.length);
      if (uncomment) {
        final markerLength = _markerLength(content);
        return '$indent${content.substring(markerLength)}';
      }
      return '$indent// $content';
    }).toList();
    final after = transformedLines.join('\n');
    final mappedBase = _mapOffset(
      base,
      text: text,
      firstLineStart: firstLineStart,
      lastLineEnd: lastLineEnd,
      lines: lines,
      transformedLines: transformedLines,
      uncomment: uncomment,
    );
    final mappedExtent = _mapOffset(
      extent,
      text: text,
      firstLineStart: firstLineStart,
      lastLineEnd: lastLineEnd,
      lines: lines,
      transformedLines: transformedLines,
      uncomment: uncomment,
    );
    return LineCommentEdit(
      offset: firstLineStart,
      before: before,
      after: after,
      selectionBase: mappedBase,
      selectionExtent: mappedExtent,
    );
  }

  int _mapOffset(
    int offset, {
    required String text,
    required int firstLineStart,
    required int lastLineEnd,
    required List<String> lines,
    required List<String> transformedLines,
    required bool uncomment,
  }) {
    if (offset <= firstLineStart) return firstLineStart;
    if (offset >= lastLineEnd) {
      return firstLineStart + transformedLines.join('\n').length;
    }
    var originalCursor = firstLineStart;
    var transformedCursor = firstLineStart;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final transformed = transformedLines[index];
      final lineEnd = originalCursor + line.length;
      if (offset <= lineEnd) {
        final indent = RegExp(r'^[ \t]*').stringMatch(line) ?? '';
        final content = line.substring(indent.length);
        final markerLength = uncomment ? _markerLength(content) : 0;
        final insertion = uncomment ? indent.length : indent.length;
        var relative = offset - originalCursor;
        if (uncomment) {
          if (relative <= insertion) {
            relative = relative;
          } else {
            relative = (relative - markerLength)
                .clamp(insertion, transformed.length)
                .toInt();
          }
        } else if (line.trim().isNotEmpty && relative >= insertion) {
          relative += 3;
        }
        return (transformedCursor + relative)
            .clamp(transformedCursor, transformedCursor + transformed.length)
            .toInt();
      }
      originalCursor += line.length;
      transformedCursor += transformed.length;
      if (index < lines.length - 1) {
        if (offset == originalCursor) {
          return transformedCursor;
        }
        originalCursor++;
        transformedCursor++;
      }
    }
    return firstLineStart + transformedLines.join('\n').length;
  }

  int _markerLength(String content) {
    if (content.startsWith('// ')) return 3;
    if (content.startsWith('//')) return 2;
    return 0;
  }
}
