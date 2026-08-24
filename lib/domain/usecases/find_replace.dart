class SearchMatch {
  final int offset;
  final int length;

  const SearchMatch({required this.offset, required this.length});
}

class ReplaceResult {
  final String text;
  final int count;

  const ReplaceResult({required this.text, required this.count});
}

class FindText {
  const FindText();

  List<SearchMatch> call(
    String text,
    String query, {
    bool caseSensitive = true,
  }) {
    if (query.isEmpty) return const [];
    final source = caseSensitive ? text : text.toLowerCase();
    final target = caseSensitive ? query : query.toLowerCase();
    final matches = <SearchMatch>[];
    var offset = 0;
    while (offset <= source.length - target.length) {
      final matchOffset = source.indexOf(target, offset);
      if (matchOffset < 0) break;
      matches.add(SearchMatch(offset: matchOffset, length: query.length));
      offset = matchOffset + target.length;
    }
    return matches;
  }
}

class ReplaceAllText {
  const ReplaceAllText();

  ReplaceResult call(
    String text,
    String query,
    String replacement, {
    bool caseSensitive = true,
  }) {
    final matches = const FindText()(text, query, caseSensitive: caseSensitive);
    if (matches.isEmpty) return ReplaceResult(text: text, count: 0);
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      buffer
        ..write(text.substring(cursor, match.offset))
        ..write(replacement);
      cursor = match.offset + match.length;
    }
    buffer.write(text.substring(cursor));
    return ReplaceResult(text: buffer.toString(), count: matches.length);
  }
}
