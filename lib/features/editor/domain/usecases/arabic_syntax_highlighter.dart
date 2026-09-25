import '../entities/source_token.dart';

/// يحول النصوص العربية إلى tokens مستقلة للعرض والتلوين دون الحاجة للمترجم مباشرة.
class ArabicSyntaxHighlighter {
  static const Map<String, SourceTokenGroup> _keywordGroups = {
    'برنامج': SourceTokenGroup.declaration,
    'ثابت': SourceTokenGroup.declaration,
    'نوع': SourceTokenGroup.declaration,
    'متغير': SourceTokenGroup.declaration,
    'اجراء': SourceTokenGroup.declaration,
    'إجراء': SourceTokenGroup.declaration,
    'اذا': SourceTokenGroup.controlFlow,
    'إذا': SourceTokenGroup.controlFlow,
    'فان': SourceTokenGroup.controlFlow,
    'والا': SourceTokenGroup.controlFlow,
    'وإلا': SourceTokenGroup.controlFlow,
    'كرر': SourceTokenGroup.controlFlow,
    'طالما': SourceTokenGroup.controlFlow,
    'استمر': SourceTokenGroup.controlFlow,
    'اعد': SourceTokenGroup.controlFlow,
    'أعد': SourceTokenGroup.controlFlow,
    'اطبع': SourceTokenGroup.builtin,
    'اقرا': SourceTokenGroup.builtin,
    'اقرأ': SourceTokenGroup.builtin,
    'صحيح': SourceTokenGroup.type,
    'حقيقي': SourceTokenGroup.type,
    'منطقي': SourceTokenGroup.type,
    'حرفي': SourceTokenGroup.type,
    'خيط_رمزي': SourceTokenGroup.type,
    'قائمة': SourceTokenGroup.type,
    'سجل': SourceTokenGroup.type,
    'بالقيمة': SourceTokenGroup.modifier,
    'بالمرجع': SourceTokenGroup.modifier,
    'من': SourceTokenGroup.modifier,
    'الى': SourceTokenGroup.modifier,
    'اضف': SourceTokenGroup.modifier,
    'أضف': SourceTokenGroup.modifier,
    'حتى': SourceTokenGroup.modifier,
  };

  static const Set<String> _booleans = {'صح', 'خطأ'};

  static const Set<String> _punctuation = {
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    ';',
    '؛',
    ',',
    '،',
    '.',
    ':',
  };

  static const Set<String> _twoCharOperators = {
    '&&',
    '||',
    '==',
    '!=',
    '=<',
    '=>',
  };

  static const Set<String> _singleCharOperators = {
    '+',
    '-',
    '*',
    '/',
    '%',
    r'\',
    '^',
    '!',
    '=',
    '<',
    '>',
  };

  const ArabicSyntaxHighlighter();

  List<SourceToken> tokenize(
    String source, {
    Map<String, SourceTokenRole> roles = const {},
  }) {
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

    var index = 0;
    while (index < source.length) {
      if (comments.any((c) => index >= c.start && index < c.end)) {
        index++;
        continue;
      }

      final char = source[index];

      // تجاهل المسافات
      if (char.trim().isEmpty) {
        index++;
        continue;
      }

      // سلاسل نصية
      if (char == '"') {
        final start = index;
        index++;
        while (index < source.length && source[index] != '"') {
          if (source[index] == '\n') break;
          index++;
        }
        if (index < source.length && source[index] == '"') index++;
        tokens.add(
          SourceToken(
            kind: SourceTokenKind.string,
            lexeme: source.substring(start, index),
            start: start,
            end: index,
          ),
        );
        continue;
      }

      // محارف
      if (char == '’' || char == '‘' || char == '\'') {
        final start = index;
        index++;
        if (index < source.length) index++;
        if (index < source.length &&
            (source[index] == '’' ||
                source[index] == '‘' ||
                source[index] == '\'')) {
          index++;
        }
        tokens.add(
          SourceToken(
            kind: SourceTokenKind.character,
            lexeme: source.substring(start, index),
            start: start,
            end: index,
          ),
        );
        continue;
      }

      // أرقام
      if (_isDigit(char)) {
        final start = index;
        while (index < source.length && _isDigit(source[index])) {
          index++;
        }
        var isReal = false;
        if (index + 1 < source.length &&
            source[index] == '.' &&
            _isDigit(source[index + 1])) {
          isReal = true;
          index++;
          while (index < source.length && _isDigit(source[index])) {
            index++;
          }
        }
        tokens.add(
          SourceToken(
            kind: isReal ? SourceTokenKind.real : SourceTokenKind.integer,
            lexeme: source.substring(start, index),
            start: start,
            end: index,
          ),
        );
        continue;
      }

      // معرفات وكلمات مفتاحية
      if (_isArabicLetter(char) || char == '_') {
        final start = index;
        while (index < source.length &&
            (_isArabicLetter(source[index]) ||
                _isDigit(source[index]) ||
                source[index] == '_')) {
          index++;
        }
        final lexeme = source.substring(start, index);
        final group = _keywordGroups[lexeme];
        final SourceTokenKind kind;
        if (_booleans.contains(lexeme)) {
          kind = SourceTokenKind.boolean;
        } else if (group != null) {
          kind = SourceTokenKind.keyword;
        } else {
          kind = SourceTokenKind.identifier;
        }
        tokens.add(
          SourceToken(
            kind: kind,
            lexeme: lexeme,
            start: start,
            end: index,
            role: roles[lexeme],
            group: group,
          ),
        );
        continue;
      }

      // علامات ترقيم
      if (_punctuation.contains(char)) {
        tokens.add(
          SourceToken(
            kind: SourceTokenKind.punctuation,
            lexeme: char,
            start: index,
            end: index + 1,
          ),
        );
        index++;
        continue;
      }

      // معاملات بحرفين
      if (index + 1 < source.length) {
        final twoChars = source.substring(index, index + 2);
        if (_twoCharOperators.contains(twoChars)) {
          tokens.add(
            SourceToken(
              kind: SourceTokenKind.operator,
              lexeme: twoChars,
              start: index,
              end: index + 2,
            ),
          );
          index += 2;
          continue;
        }
      }

      // معاملات بحرف واحد
      if (_singleCharOperators.contains(char)) {
        tokens.add(
          SourceToken(
            kind: SourceTokenKind.operator,
            lexeme: char,
            start: index,
            end: index + 1,
          ),
        );
        index++;
        continue;
      }

      // أي رمز آخر
      index++;
    }

    tokens.sort((left, right) => left.start.compareTo(right.start));
    return List.unmodifiable(tokens);
  }

  static bool _isDigit(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isArabicLetter(String char) {
    if (char.isEmpty || char == '؛' || char == '،') return false;
    final code = char.codeUnitAt(0);
    return (code >= 0x0600 && code <= 0x06ff) ||
        (code >= 0x0750 && code <= 0x077f) ||
        (code >= 0x08a0 && code <= 0x08ff);
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
      if (!inString && (current == '‘' || current == '’' || current == '\'')) {
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
