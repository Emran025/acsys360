import '../lexer/lexer.dart';
import '../model/token.dart';
import 'language_catalog.dart';

class CompletionItem {
  final String label;
  final String insertText;
  final String kind;
  final String detail;

  const CompletionItem({
    required this.label,
    required this.insertText,
    required this.kind,
    required this.detail,
  });
}

class CompletionResult {
  final String prefix;
  final int replaceStart;
  final int replaceLength;
  final String expected;
  final List<CompletionItem> items;

  const CompletionResult({
    required this.prefix,
    required this.replaceStart,
    required this.replaceLength,
    required this.expected,
    required this.items,
  });
}

class LanguageAssist {
  const LanguageAssist();

  CompletionResult complete(
    String source,
    int offset, {
    Iterable<String> symbols = const [],
  }) {
    final safeOffset = offset.clamp(0, source.length).toInt();
    final prefixStart = _prefixStart(source, safeOffset);
    final prefix = source.substring(prefixStart, safeOffset);
    final context = _context(source, prefixStart);
    final items = <CompletionItem>[];

    for (final entry in LanguageCatalog.entries) {
      if (_matches(entry.keyword, prefix)) {
        items.add(
          CompletionItem(
            label: entry.keyword,
            insertText: entry.keyword,
            kind: 'keyword',
            detail: entry.title,
          ),
        );
      }
    }
    for (final symbol in symbols.toSet()) {
      if (_matches(symbol, prefix)) {
        items.add(
          CompletionItem(
            label: symbol,
            insertText: symbol,
            kind: 'symbol',
            detail: 'رمز معرّف في المشروع',
          ),
        );
      }
    }
    items.sort((left, right) {
      final leftMatches = _startsWithPrefix(left.label, prefix);
      final rightMatches = _startsWithPrefix(right.label, prefix);
      if (leftMatches != rightMatches) return rightMatches ? 1 : -1;
      return left.label.compareTo(right.label);
    });
    return CompletionResult(
      prefix: prefix,
      replaceStart: prefixStart,
      replaceLength: safeOffset - prefixStart,
      expected: context.expected,
      items: items,
    );
  }

  LanguageHelpEntry? helpFor(String source, int offset) {
    final safeOffset = offset.clamp(0, source.length).toInt();
    final prefixStart = _prefixStart(source, safeOffset);
    final prefix = source.substring(prefixStart, safeOffset);
    if (prefix.isNotEmpty) return _helpForPrefix(prefix);
    final tokens = _tokensBefore(source, safeOffset);
    if (tokens.isEmpty) return LanguageCatalog.byKeyword['برنامج'];
    return LanguageCatalog.byKeyword[tokens.last.lexeme];
  }

  _AssistContext _context(String source, int offset) {
    final tokens = _tokensBefore(source, offset);
    if (tokens.isEmpty) return const _AssistContext('كلمة برنامج');
    final last = tokens.last.lexeme;
    return switch (last) {
      'برنامج' => const _AssistContext('اسم البرنامج'),
      'ثابت' => const _AssistContext('اسم الثابت'),
      'نوع' => const _AssistContext('اسم النوع'),
      'متغير' => const _AssistContext('اسم المتغير'),
      'اجراء' => const _AssistContext('اسم الإجراء'),
      'بالقيمة' || 'بالمرجع' => const _AssistContext('أسماء المعاملات'),
      'اذا' || 'طالما' || 'كرر' => const _AssistContext('قوسا الشرط أو المجال'),
      'فان' || 'والا' || 'استمر' || 'اعد' => const _AssistContext('تعليمة'),
      'من' => const _AssistContext('نوع البيانات'),
      ':' => const _AssistContext('نوع البيانات'),
      '(' => const _AssistContext('تعبير أو معامل'),
      '=' => const _AssistContext('قيمة أو تعبير'),
      _ => const _AssistContext('كلمة أو اسم معرف'),
    };
  }

  LanguageHelpEntry? _helpForPrefix(String prefix) {
    final exact = LanguageCatalog.byKeyword[prefix];
    if (exact != null) return exact;
    for (final entry in LanguageCatalog.entries) {
      if (entry.keyword.startsWith(prefix)) return entry;
    }
    return null;
  }

  List<Token> _tokensBefore(String source, int offset) {
    final tokens = Lexer(source.substring(0, offset)).scan().tokens;
    return [
      for (final token in tokens)
        if (token.kind != TokenKind.eof) token,
    ];
  }

  int _prefixStart(String source, int offset) {
    var start = offset;
    while (start > 0 && _isIdentifierChar(source[start - 1])) start--;
    return start;
  }

  bool _matches(String value, String prefix) =>
      prefix.isEmpty || value.startsWith(prefix);

  bool _startsWithPrefix(String value, String prefix) =>
      prefix.isEmpty || value.startsWith(prefix);

  bool _isIdentifierChar(String value) =>
      RegExp(r'[\u0600-\u06ff0-9_]').hasMatch(value);
}

class _AssistContext {
  final String expected;

  const _AssistContext(this.expected);
}
