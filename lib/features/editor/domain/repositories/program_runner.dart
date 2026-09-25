import 'workspace_repository.dart';

typedef NativeOutputHandler = void Function(String line);

abstract interface class ProgramRunner {
  Future<List<String>> run(
    String executable, {
    InputRequestHandler? onInputRequest,
    NativeOutputHandler? onOutput,
  });
}

class UnavailableProgramRunner implements ProgramRunner {
  const UnavailableProgramRunner();

  @override
  Future<List<String>> run(
    String executable, {
    InputRequestHandler? onInputRequest,
    NativeOutputHandler? onOutput,
  }) => throw StateError('لم يتم إعداد مشغل البرنامج التنفيذي');
}
