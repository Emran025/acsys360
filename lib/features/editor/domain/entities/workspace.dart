import 'document.dart';

class Workspace {
  final String rootPath;
  final List<Document> documents;
  final int activeIndex;

  const Workspace({
    required this.rootPath,
    this.documents = const [],
    this.activeIndex = -1,
  });

  Document? get activeDocument =>
      activeIndex >= 0 && activeIndex < documents.length
      ? documents[activeIndex]
      : null;

  Workspace open(Document document) {
    final existing = documents.indexWhere((item) => item.path == document.path);
    if (existing >= 0) return copyWith(activeIndex: existing);
    return copyWith(
      documents: [...documents, document],
      activeIndex: documents.length,
    );
  }

  Workspace replaceActive(Document document) {
    if (activeIndex < 0) return open(document);
    final next = [...documents]..[activeIndex] = document;
    return copyWith(documents: next);
  }

  Workspace close(int index) {
    if (index < 0 || index >= documents.length) return this;
    final next = [...documents]..removeAt(index);
    if (next.isEmpty) return copyWith(documents: next, activeIndex: -1);
    final nextIndex = activeIndex > index
        ? activeIndex - 1
        : (activeIndex == index
              ? (index >= next.length ? next.length - 1 : index)
              : activeIndex);
    return copyWith(documents: next, activeIndex: nextIndex);
  }

  Workspace closeActive() => close(activeIndex);

  Workspace select(int index) => index >= 0 && index < documents.length
      ? copyWith(activeIndex: index)
      : this;

  Workspace copyWith({
    String? rootPath,
    List<Document>? documents,
    int? activeIndex,
  }) => Workspace(
    rootPath: rootPath ?? this.rootPath,
    documents: documents ?? this.documents,
    activeIndex: activeIndex ?? this.activeIndex,
  );
}
