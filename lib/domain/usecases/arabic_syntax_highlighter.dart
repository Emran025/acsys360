import 'package:compiler_core/arabic_compiler.dart';

import '../entities/source_token.dart';

/// يحول Lexer الحقيقي إلى spans مستقلة عن Flutter؛ لا يعيد تعريف grammar داخل Widget.
class ArabicSyntaxHighlighter {
  const ArabicSyntaxHighlighter();

  List<SourceToken> tokenize(
    String source, {
    Map<String, SourceTokenRole> roles = const {},
  }) {
    final lexical = Lexer(source).scan();
    final tokens = <SourceToken>[];
    final comments = _commentRanges(source);

    for (final comment in comments) {
      tokens.add(
        SourceToken(
          kind: SourceTokenKind.comment,
          lexeme: source.substring(comment.start, comment.end),
          start: comment.start,
          end: comment.end,
        ),
      );
    }

    for (final token in lexical.tokens) {
      if (token.kind == TokenKind.eof) continue;
      final start = token.position.offset;
      final end = (start + _sourceLength(token, source)).clamp(
        start,
        source.length,
      );
      if (comments.any(
        (comment) => start >= comment.start && start < comment.end,
      )) {
        continue;
      }
      tokens.add(
        SourceToken(
          kind: _kind(token.kind),
          lexeme: source.substring(start, end),
          start: start,
          end: end,
          role: roles[token.lexeme],
        ),
      );
    }

    tokens.sort((left, right) => left.start.compareTo(right.start));
    return List.unmodifiable(tokens);
  }

  SourceTokenKind _kind(TokenKind kind) => switch (kind) {
    TokenKind.identifier => SourceTokenKind.identifier,
    TokenKind.keyword => SourceTokenKind.keyword,
    TokenKind.integer => SourceTokenKind.integer,
    TokenKind.real => SourceTokenKind.real,
    TokenKind.string => SourceTokenKind.string,
    TokenKind.character => SourceTokenKind.character,
    TokenKind.boolean => SourceTokenKind.boolean,
    TokenKind.operator => SourceTokenKind.operator,
    TokenKind.punctuation => SourceTokenKind.punctuation,
    TokenKind.eof => SourceTokenKind.punctuation,
  };

  int _sourceLength(Token token, String source) {
    final delimiterLength = switch (token.kind) {
      TokenKind.string || TokenKind.character => 2,
      _ => 0,
    };
    return token.lexeme.length + delimiterLength;
  }

  List<({int start, int end})> _commentRanges(String source) {
    final ranges = <({int start, int end})>[];
    var index = 0;
    var inString = false;
    var inCharacter = false;
    while (index < source.length) {
      final current = source[index];
      if (!inCharacter && current == '"') {
        inString = !inString;
        index++;
        continue;
      }
      if (!inString && (current == '‘' || current == '’')) {
        inCharacter = !inCharacter;
        index++;
        continue;
      }
      if (!inString &&
          !inCharacter &&
          current == '/' &&
          index + 1 < source.length &&
          source[index + 1] == '/') {
        final start = index;
        final newline = source.indexOf('\n', index);
        final end = newline == -1 ? source.length : newline;
        ranges.add((start: start, end: end));
        index = end;
        continue;
      }
      index++;
    }
    return ranges;
  }
}
