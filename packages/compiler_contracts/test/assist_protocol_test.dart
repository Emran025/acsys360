import 'package:compiler_contracts/compiler_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips a completion request', () {
    const request = AssistRequest(
      sourcePath: 'main.arb',
      sourceText: 'مت',
      offset: 2,
      action: AssistAction.completion,
      symbols: ['متغير'],
    );

    final decoded = AssistRequest.fromJson(
      Map<String, dynamic>.from(request.toJson()),
    );

    expect(decoded.action, AssistAction.completion);
    expect(decoded.sourceText, 'مت');
    expect(decoded.offset, 2);
    expect(decoded.symbols, ['متغير']);
  });

  test('round-trips completion items and contextual help', () {
    const response = AssistResponse(
      action: AssistAction.completion,
      expected: 'نوع البيانات',
      prefix: 'ص',
      replaceStart: 8,
      replaceLength: 1,
      items: [
        AssistCompletionItem(
          label: 'صحيح',
          insertText: 'صحيح',
          kind: 'keyword',
          detail: 'نوع صحيح',
        ),
      ],
      help: AssistHelp(
        keyword: 'متغير',
        title: 'تعريف المتغيرات',
        description: 'يعرّف متغيرًا.',
        syntax: 'متغير الاسم: نوع_البيانات؛',
      ),
    );

    final decoded = AssistResponse.fromJson(
      Map<String, dynamic>.from(response.toJson()),
    );

    expect(decoded.items.single.label, 'صحيح');
    expect(decoded.expected, 'نوع البيانات');
    expect(decoded.help?.keyword, 'متغير');
  });
}
