import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:acsys360/features/editor/data/datasources/native_artifact_builder.dart';

void main() {
  test('builds the compiler assembly into a native executable', () async {
    if (!File('/usr/bin/nasm').existsSync() || !File('/usr/bin/gcc').existsSync()) {
      return;
    }
    final directory = await Directory.systemTemp.createTemp('arabicc-artifact-');
    addTearDown(() => directory.delete(recursive: true));
    const assembly = '''default rel
global main
extern printf
section .data
fmt: db "%ld", 10, 0
section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov rsi, 42
    lea rdi, [rel fmt]
    xor eax, eax
    call printf
    xor eax, eax
    leave
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
''';
    final artifact = await const NativeArtifactBuilder().build(
      assembly: assembly,
      outputDirectory: directory.path,
      baseName: 'main.arb',
    );
    expect(File(artifact).existsSync(), isTrue);
    final result = await Process.run(artifact, const []);
    expect(result.exitCode, 0);
    expect('${result.stdout}'.trim(), '42');
  });
}
