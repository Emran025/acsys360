import 'dart:io';

import 'package:acsys360/features/editor/data/datasources/native_artifact_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File executable;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acsys360-runner-');
    executable = File('${directory.path}/program.sh');
    await executable.writeAsString('''#!/bin/sh
printf '%s\\n' 'hello'
printf '%s\\n' '{"requestType":"input","name":"الاسم","type":"نص"}'
read value
printf 'got:%s\\n' "\$value"
''');
    await Process.run('chmod', ['+x', executable.path]);
  });

  tearDown(() => directory.delete(recursive: true));

  test('returns output and serves interactive input requests', () async {
    final output = await const NativeArtifactRunner().run(
      executable.path,
      onInputRequest: (request) async {
        expect(request.name, 'الاسم');
        expect(request.type, 'نص');
        return 'علي';
      },
    );
    expect(output, ['hello', 'got:علي']);
  });

  test('rejects missing executables', () {
    expect(
      () => const NativeArtifactRunner().run('${executable.path}.missing'),
      throwsStateError,
    );
  });
}
