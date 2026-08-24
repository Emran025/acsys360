import 'package:acsys360/domain/usecases/find_replace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const find = FindText();
  const replace = ReplaceAllText();

  test('finds non-overlapping Arabic matches', () {
    final matches = find('اكتب اكتب برنامج', 'اكتب');

    expect(matches.map((match) => match.offset), [0, 5]);
    expect(matches.map((match) => match.length), [4, 4]);
  });

  test('supports case-insensitive search', () {
    final matches = find('برنامج PROGRAM', 'program', caseSensitive: false);

    expect(matches.length, 1);
    expect(matches.single.offset, 7);
  });

  test('replaces all matches as one result', () {
    final result = replace('اكتب اكتب', 'اكتب', 'نفذ');

    expect(result.count, 2);
    expect(result.text, 'نفذ نفذ');
  });

  test('empty query leaves source unchanged', () {
    final result = replace('نص', '', 'بديل');

    expect(result.count, 0);
    expect(result.text, 'نص');
  });
}
