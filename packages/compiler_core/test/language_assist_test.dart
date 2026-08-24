import 'package:compiler_core/arabic_compiler.dart';
import 'package:test/test.dart';

void main() {
  const assist = LanguageAssist();

  test('suggests official Arabic keywords by prefix', () {
    final result = assist.complete('مت', 2);

    expect(result.prefix, 'مت');
    expect(result.replaceStart, 0);
    expect(result.replaceLength, 2);
    expect(result.items.map((item) => item.label), contains('متغير'));
    expect(result.items.every((item) => item.kind == 'keyword'), isTrue);
  });

  test('suggests project symbols and expects a data type after colon', () {
    const source = 'متغير س: ص';
    final result = assist.complete(
      source,
      source.length,
      symbols: ['صحيح', 'سعر'],
    );

    expect(result.prefix, 'ص');
    expect(result.expected, 'نوع البيانات');
    expect(result.items.map((item) => item.label), contains('صحيح'));
    expect(result.items.map((item) => item.label), isNot(contains('سعر')));
  });

  test('returns contextual help for a complete keyword', () {
    const source = 'برنامج ';
    final help = assist.helpFor(source, source.length);

    expect(help?.keyword, 'برنامج');
    expect(help?.syntax, contains('اسم_البرنامج'));
  });

  test('returns help for an incomplete keyword prefix', () {
    final help = assist.helpFor('طال', 3);

    expect(help?.keyword, 'طالما');
    expect(help?.description, contains('يكرر'));
  });
}
