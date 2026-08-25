class TextEdit {
  final int offset;
  final String before;
  final String after;

  const TextEdit({
    required this.offset,
    required this.before,
    required this.after,
  });
}

class Document {
  final String path;
  final String text;
  final String savedText;
  final List<TextEdit> undoStack;
  final List<TextEdit> redoStack;

  const Document({
    required this.path,
    required this.text,
    String? savedText,
    this.undoStack = const [],
    this.redoStack = const [],
  }) : savedText = savedText ?? text;

  bool get isDirty => text != savedText;

  /// يطبق تعديلًا ذريًا واحدًا؛ التحقق يمنع الكتابة فوق snapshot قديم.
  Document edit(TextEdit change) {
    _validateEdit(change);
    final nextText = text.replaceRange(
      change.offset,
      change.offset + change.before.length,
      change.after,
    );
    return Document(
      path: path,
      text: nextText,
      savedText: savedText,
      undoStack: [...undoStack, change],
      redoStack: const [],
    );
  }

  Document undo() {
    if (undoStack.isEmpty) return this;
    final change = undoStack.last;
    final currentOffset = change.offset;
    final restored = text.replaceRange(
      currentOffset,
      currentOffset + change.after.length,
      change.before,
    );
    return Document(
      path: path,
      text: restored,
      savedText: savedText,
      undoStack: undoStack.sublist(0, undoStack.length - 1),
      redoStack: [...redoStack, change],
    );
  }

  Document redo() {
    if (redoStack.isEmpty) return this;
    final change = redoStack.last;
    final applied = text.replaceRange(
      change.offset,
      change.offset + change.before.length,
      change.after,
    );
    return Document(
      path: path,
      text: applied,
      savedText: savedText,
      undoStack: [...undoStack, change],
      redoStack: redoStack.sublist(0, redoStack.length - 1),
    );
  }

  /// يحافظ على Document كمصدر الحقيقة الوحيد للنص وسجل undo/redo.
  void _validateEdit(TextEdit change) {
    if (change.offset < 0 || change.offset > text.length) {
      throw RangeError.range(change.offset, 0, text.length, 'offset');
    }
    final end = change.offset + change.before.length;
    if (end > text.length ||
        text.substring(change.offset, end) != change.before) {
      throw StateError('تعديل المستند لا يطابق النص الحالي');
    }
  }

  Document markSaved() => Document(
    path: path,
    text: text,
    savedText: text,
    undoStack: undoStack,
    redoStack: redoStack,
  );
}
