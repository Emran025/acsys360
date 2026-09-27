import 'dart:convert';
import 'dart:io';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  check(args.length == 1, 'usage: procedure_abi.dart <arabicc>');
  final artifactDirectory = Directory.systemTemp.createTempSync(
    'arabicc-procedure-abi-',
  );
  try {
    final request = <String, dynamic>{
      'protocolVersion': '0.5.0',
      'rootPath': artifactDirectory.path,
      'artifactDirectory': artifactDirectory.path,
      'sourcePaths': ['procedures.arb'],
      'sourceTexts': {
        'procedures.arb': '''
برنامج اختبار_الاجراءات؛
متغير الناتج: صحيح؛
متغير المعدل: حقيقي؛
إجراء جمع_بالقيمة(بالقيمة ا: صحيح؛ بالقيمة ب: صحيح)؛
{
  اطبع(ا + ب)؛
}؛
إجراء زد_بالمرجع(بالمرجع ن: صحيح)؛
{
  ن = ن + 1؛
}؛
إجراء بلا_وسائط()؛
{
  اطبع(9)؛
}؛
إجراء اطبع_بالمرجع(بالمرجع قيمة_حقيقية: حقيقي)؛
{
  اطبع(قيمة_حقيقية)؛
}؛
{
  الناتج = 4؛
  المعدل = 1.5؛
  جمع_بالقيمة(2, 3)؛
  زد_بالمرجع(الناتج)؛
  بلا_وسائط()؛
  اطبع_بالمرجع(المعدل)؛
  اطبع(الناتج)؛
}.
''',
      },
      'mode': 'project',
      'entryPath': 'procedures.arb',
      'target': 'dart-native',
      'execute': false,
    };
    final process = await Process.start(args.single, ['--protocol']);
    process.stdin.writeln(jsonEncode(request));
    await process.stdin.close();
    final stdout = (await process.stdout.transform(utf8.decoder).join()).trim();
    final stderr = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    check(stdout.isNotEmpty, 'compiler returned no JSON: $stderr');
    final response = jsonDecode(stdout) as Map<String, dynamic>;
    check(
      exitCode == 0 && response['success'] == true,
      'procedure compilation failed: ${response['diagnostics']}',
    );

    final tac = (response['threeAddressCode'] as List).cast<String>();
    check(
      tac.contains('PROCEDURE_BEGIN جمع_بالقيمة'),
      'procedure definition is missing from TAC: ${tac.join(' | ')}',
    );
    check(
      tac.contains('PROCEDURE_PARAMETER ا, 0 بالقيمة'),
      'by-value parameter metadata is missing from TAC: ${tac.join(' | ')}',
    );
    check(
      tac.contains('PROCEDURE_PARAMETER ن, 0 بالمرجع'),
      'by-reference parameter metadata is missing from TAC: ${tac.join(' | ')}',
    );
    check(
      tac.contains('CALL جمع_بالقيمة, 2') &&
          tac.contains('CALL زد_بالمرجع, 1') &&
          tac.contains('CALL بلا_وسائط, 0') &&
          tac.contains('CALL اطبع_بالمرجع, 1'),
      'procedure calls or argument counts are missing from TAC',
    );

    final assembly = response['assembly'] as String;
    check(
      assembly.contains('proc_0:') &&
          assembly.contains('proc_1:') &&
          assembly.contains('proc_2:') &&
          assembly.contains('proc_3:'),
      'NASM procedure labels are missing',
    );
    check(
      assembly.contains('call proc_0') &&
          assembly.contains('call proc_1') &&
          assembly.contains('call proc_2') &&
          assembly.contains('call proc_3'),
      'procedure CALL instructions were not lowered',
    );
    check(
      assembly.contains('[rbp+16]'),
      'callee argument loading does not match the stack ABI',
    );
    check(
      assembly.contains('lea rax, [rel global_0]'),
      'by-reference global argument address was not passed',
    );
    check(
      assembly.contains('mov [rcx], rax'),
      'by-reference parameter assignment was not lowered',
    );
    check(
      assembly.contains('movsd xmm0, [rax]'),
      'by-reference real parameter was not loaded as a real value',
    );
    final artifacts = (response['artifacts'] as List).cast<String>();
    final executables = artifacts
        .where((path) => path.endsWith('.exe'))
        .toList();
    check(executables.isNotEmpty, 'native procedure executable was not built');
    final nativeRun = await Process.run(executables.single, const []);
    check(
      nativeRun.exitCode == 0 &&
          (nativeRun.stdout as String).trim().split('\r\n').join('\n') ==
              '5\n9\n1.5\n5',
      'native procedure output was incorrect: ${nativeRun.stdout}; '
      '${nativeRun.stderr}',
    );

    final invalidRequest = Map<String, dynamic>.from(request)
      ..['sourceTexts'] = {
        'procedures.arb': '''
برنامج اختبار_عدد_الوسائط؛
إجراء إجراء_واحد(بالقيمة قيمة: صحيح)؛ { اطبع(قيمة)؛ }؛
{ إجراء_واحد()؛ }.
''',
      };
    final invalidProcess = await Process.start(args.single, ['--protocol']);
    invalidProcess.stdin.writeln(jsonEncode(invalidRequest));
    await invalidProcess.stdin.close();
    final invalidStdout =
        (await invalidProcess.stdout.transform(utf8.decoder).join()).trim();
    await invalidProcess.stderr.drain<void>();
    final invalidExitCode = await invalidProcess.exitCode;
    check(
      invalidStdout.isNotEmpty,
      'compiler returned no JSON for invalid call',
    );
    final invalidResponse = jsonDecode(invalidStdout) as Map<String, dynamic>;
    check(
      invalidExitCode != 0 && invalidResponse['success'] == false,
      'call with the wrong number of arguments was accepted',
    );
    check(
      (invalidResponse['diagnostics'] as List).any(
        (diagnostic) =>
            (diagnostic as Map)['phase'] == 'backend' &&
            diagnostic['code'] == 'A001',
      ),
      'wrong argument count did not produce a backend diagnostic',
    );
  } finally {
    await artifactDirectory.delete(recursive: true);
  }
}
