import 'dart:io';

import 'package:compiler_contracts/compiler_contracts.dart';
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

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final dartExecutable = flutterRoot == null
        ? Platform.resolvedExecutable
        : '$flutterRoot/bin/cache/dart-sdk/bin/dart';
    final repository = ProcessCompilerRepository(
      executable: dartExecutable,
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

    expect(response['protocolVersion'], '0.5.0');
    expect(response['success'], isTrue);
    expect(response['executionOutput'], ['2', '4']);
    expect((response['syntaxTree'] as Map)['kind'], 'project');
    expect(response['tokens'], isNotEmpty);
    expect(response['intermediateRepresentation'], isA<Map>());
  });

  test('builds only the active document for a native target', () async {
    final root = await Directory.systemTemp.createTemp(
      'acsys360-native-adapter-',
    );
    addTearDown(() => root.delete(recursive: true));
    final mainPath = '${root.path}/main.arb';
    final otherPath = '${root.path}/other.arb';
    final artifactDirectory = '${root.path}/artifacts';
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final dartExecutable = flutterRoot == null
        ? Platform.resolvedExecutable
        : '$flutterRoot/bin/cache/dart-sdk/bin/dart';
    final repository = ProcessCompilerRepository(
      executable: dartExecutable,
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
        Document(path: otherPath, text: 'هذا الملف غير صالح عمدًا'),
      ],
      target: 'dart-native',
      artifactDirectory: artifactDirectory,
      mode: CompilationMode.active,
    );

    expect(response['protocolVersion'], '0.5.0');
    expect(response['success'], isTrue);
    expect(response['diagnostics'], isEmpty);
    expect(response['executionOutput'], ['2']);
    expect(response['intermediateRepresentation'], isA<Map>());
    expect(response['artifacts'], hasLength(1));
    expect(File((response['artifacts'] as List).single).existsSync(), isTrue);
  });
}

String _validProgram(String name, String value) =>
    '''برنامج اختبار {
  متغير $name: صحيح;
  $name = $value;
  اطبع($name);
}.''';
