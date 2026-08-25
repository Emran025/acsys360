import 'package:acsys360/domain/usecases/format_arabic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats indentation without changing Arabic tokens', () {
    const source = 'برنامج اختبار {\nمتغير س = 1;\n}';

    expect(formatArabicSource(source), 'برنامج اختبار {\n  متغير س = 1;\n}');
  });

  test('removes trailing spaces without changing blank lines', () {
    expect(formatArabicSource('سطر   \n\nسطر ثانٍ  '), 'سطر\n\nسطر ثانٍ');
  });

  test('does not count braces inside strings, characters, or comments', () {
    const source =
        'برنامج اختبار {\nمتغير نص = "}"; // { لا يفتح كتلة\nمتغير رمز = ‘}’;\n}.';

    expect(
      formatArabicSource(source),
      'برنامج اختبار {\n  متغير نص = "}"; // { لا يفتح كتلة\n  متغير رمز = ‘}’;\n}.',
    );
  });

  test('dedents a closing block and keeps following content aligned', () {
    const source = 'برنامج اختبار {\nمتغير س = 1;\n}\nس = 2;';

    expect(
      formatArabicSource(source),
      'برنامج اختبار {\n  متغير س = 1;\n}\nس = 2;',
    );
  });

  test('preserves CRLF line endings', () {
    const source = 'برنامج اختبار {\r\nمتغير س = 1;\r\n}';

    expect(
      formatArabicSource(source),
      'برنامج اختبار {\r\n  متغير س = 1;\r\n}',
    );
  });

  test('leaves an unterminated literal untouched', () {
    const source = 'برنامج اختبار {\nمتغير نص = "{;\n';

    expect(formatArabicSource(source), source);
  });
}
