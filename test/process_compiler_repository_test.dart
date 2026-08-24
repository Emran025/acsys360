import 'dart:io';

import 'package:acsys360/data/repositories/process_compiler_repository.dart';
import 'package:acsys360/domain/entities/document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compiles open documents through the JSON CLI protocol', () async {
    final root = await Directory.systemTemp.createTemp('acsys360-adapter-');
    addTearDown(() => root.delete(recursive: true));
    final mainPath = '${root.path}/main.arb';
    final libPath = '${root.path}/lib.arb';
    await File(mainPath).writeAsString('هذا الملف على القرص غير صالح');
    await File(libPath).writeAsString('هذا الملف على القرص غير صالح');

    final repository = ProcessCompilerRepository(
      executable: Platform.resolvedExecutable,
      arguments: [
        'run',
        'packages/compiler_core/bin/arabicc.dart',
        '--protocol',
      ],
      processWorkingDirectory: Directory.current.path,
    );
    final response = await repository.compile(
      rootPath: root.path,
      sourcePath: mainPath,
      documents: [
        Document(path: mainPath, text: _validProgram('س', '2')),
        Document(path: libPath, text: _validProgram('ص', '4')),
      ],
    );

    expect(response['protocolVersion'], '0.2.0');
    expect(response['success'], isTrue);
    expect((response['syntaxTree'] as Map)['kind'], 'project');
    expect(response['tokens'], isNotEmpty);
  });
}

String _validProgram(String name, String value) =>
    '''برنامج اختبار {
  متغير $name: صحيح;
  $name = $value;
  اطبع($name);
}.''';
