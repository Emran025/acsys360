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
}
