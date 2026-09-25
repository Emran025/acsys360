import 'package:acsys360/features/editor/domain/entities/source_token.dart';
import 'package:acsys360/features/editor/domain/usecases/arabic_syntax_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const highlighter = ArabicSyntaxHighlighter();

  test('uses compiler lexer categories and keeps comment ranges', () {
    const source = 'برنامج اختبار؛ {\n  س = "// ليس تعليقًا"; // تعليق\n}.';
    final tokens = highlighter.tokenize(source);

    expect(
      tokens.where((token) => token.kind == SourceTokenKind.comment),
      hasLength(1),
    );
    expect(
      tokens
          .where((token) => token.kind == SourceTokenKind.string)
          .single
          .lexeme,
      '"// ليس تعليقًا"',
    );
    expect(
      tokens
          .where((token) => token.kind == SourceTokenKind.keyword)
          .map((token) => token.lexeme),
      contains('برنامج'),
    );
  });

  test('applies semantic roles without changing source ranges', () {
    const source = 'س = 1;';
    final tokens = highlighter.tokenize(
      source,
      roles: const {'س': SourceTokenRole.constant},
    );
    final symbol = tokens.firstWhere((token) => token.lexeme == 'س');

    expect(symbol.kind, SourceTokenKind.identifier);
    expect(symbol.role, SourceTokenRole.constant);
    expect(source.substring(symbol.start, symbol.end), 'س');
  });

  test('recognizes the compiler lexer spellings and rejects invented aliases', () {
    const source = 'إجراء اقرأ إذا وإلا أعد أضف خيط_رمزي خيط';
    final tokens = highlighter.tokenize(source);

    for (final word in <String>[
      'إجراء',
      'اقرأ',
      'إذا',
      'وإلا',
      'أعد',
      'أضف',
      'خيط_رمزي',
    ]) {
      expect(
        tokens.firstWhere((token) => token.lexeme == word).kind,
        SourceTokenKind.keyword,
      );
    }
    expect(
      tokens.firstWhere((token) => token.lexeme == 'خيط').kind,
      SourceTokenKind.identifier,
    );
  });
}
