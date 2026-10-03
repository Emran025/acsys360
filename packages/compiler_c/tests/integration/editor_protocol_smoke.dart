import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<Map<String, dynamic>> request(
  String executable,
  List<String> arguments,
  Map<String, Object?> payload,
) async {
  final process = await Process.start(executable, arguments);
  process.stdin.writeln(jsonEncode(payload));
  await process.stdin.close();
  final output = (await process.stdout.transform(utf8.decoder).join()).trim();
  final error = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  check(output.isNotEmpty, 'compiler returned no JSON: $error');
  final decoded = jsonDecode(output) as Map<String, dynamic>;
  if (arguments.contains('--protocol') && decoded['success'] == true) {
    check(exitCode == 0, 'successful compile returned exit code $exitCode');
  }
  return decoded;
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: editor_protocol_smoke.dart <arabicc>');
  final executable = args.single;
  final source = 'برنامج موقع؛ متغير العدد: صحيح؛ { اطبع("🙂")؛ مجهول = 1؛ }.';
  final semantic = await request(
    executable,
    const ['--protocol'],
    {
      'protocolVersion': '0.5.0',
      'rootPath': '.',
      'sourcePaths': ['main.arb'],
      'sourceTexts': {'main.arb': source},
      'mode': 'active',
      'entryPath': 'main.arb',
      'execute': false,
    },
  );
  final semanticDiagnostic = (semantic['diagnostics'] as List)
      .cast<Map>()
      .firstWhere((diagnostic) => diagnostic['phase'] == 'semantic');
  final semanticSpan = semanticDiagnostic['span'] as Map;
  final unknownOffset = source.indexOf('مجهول');
  check(
    semanticSpan['offset'] == unknownOffset &&
        semanticSpan['length'] == 'مجهول'.length &&
        semanticSpan['line'] == 1 &&
        semanticSpan['column'] == unknownOffset + 1,
    'semantic error span did not select the unknown identifier: $semanticSpan',
  );

  const unsupportedCharacterSource = 'برنامج محرف؛ { اطبع(🙂)؛ }.';
  final unsupportedCharacter = await request(
    executable,
    const ['--protocol'],
    {
      'protocolVersion': '0.5.0',
      'rootPath': '.',
      'sourcePaths': ['main.arb'],
      'sourceTexts': {'main.arb': unsupportedCharacterSource},
      'mode': 'active',
      'entryPath': 'main.arb',
      'execute': false,
    },
  );
  final lexicalDiagnostic = (unsupportedCharacter['diagnostics'] as List)
      .cast<Map>()
      .firstWhere((diagnostic) => diagnostic['phase'] == 'lexical');
  final lexicalSpan = lexicalDiagnostic['span'] as Map;
  check(
    lexicalSpan['offset'] == unsupportedCharacterSource.indexOf('🙂') &&
        lexicalSpan['length'] == '🙂'.length &&
        lexicalSpan['line'] == 1,
    'unsupported UTF-8 character span was split or miscounted: $lexicalSpan',
  );

  const missingSemicolon = 'برنامج فاصلة؛ { اطبع(1) }.';
  final syntax = await request(
    executable,
    const ['--protocol'],
    {
      'protocolVersion': '0.5.0',
      'rootPath': '.',
      'sourcePaths': ['main.arb'],
      'sourceTexts': {'main.arb': missingSemicolon},
      'mode': 'active',
      'entryPath': 'main.arb',
      'execute': false,
    },
  );
  final syntaxDiagnostic = (syntax['diagnostics'] as List)
      .cast<Map>()
      .firstWhere((diagnostic) => diagnostic['phase'] == 'syntax');
  final syntaxSpan = syntaxDiagnostic['span'] as Map;
  check(
    syntaxSpan['offset'] == missingSemicolon.lastIndexOf('}') &&
        syntaxSpan['length'] == 1 &&
        (syntaxDiagnostic['message'] as String).contains('متوقع "؛"'),
    'missing punctuation was not anchored at the unexpected token: '
    '$syntaxDiagnostic',
  );

  const missingDot = 'برنامج نهاية؛ { }';
  final eof = await request(
    executable,
    const ['--protocol'],
    {
      'protocolVersion': '0.5.0',
      'rootPath': '.',
      'sourcePaths': ['main.arb'],
      'sourceTexts': {'main.arb': missingDot},
      'mode': 'active',
      'entryPath': 'main.arb',
      'execute': false,
    },
  );
  final eofDiagnostic = (eof['diagnostics'] as List).cast<Map>().firstWhere(
    (diagnostic) => diagnostic['phase'] == 'syntax',
  );
  final eofSpan = eofDiagnostic['span'] as Map;
  check(
    eofSpan['offset'] == missingDot.length &&
        eofSpan['length'] == 0 &&
        (eofDiagnostic['message'] as String).contains('متوقع "."'),
    'end-of-file diagnostic did not use a zero-length insertion point: '
    '$eofDiagnostic',
  );

  const assistSource = '🙂؛ال';
  final assist = await request(
    executable,
    const ['--assist'],
    {
      'protocolVersion': '0.5.0',
      'requestType': 'assist',
      'sourcePath': 'main.arb',
      'sourceText': assistSource,
      'offset': assistSource.length,
      'action': 'completion',
      'symbols': ['العدد'],
    },
  );
  final items = (assist['items'] as List).cast<Map>();
  check(
    assist['prefix'] == 'ال' &&
        assist['replaceStart'] == assistSource.indexOf('ال') &&
        assist['replaceLength'] == 2 &&
        items.any((item) => item['label'] == 'العدد'),
    'completion failed across Arabic punctuation or UTF-16 offsets: $assist',
  );
}
