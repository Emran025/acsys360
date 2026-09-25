import 'workspace_repository.dart';

typedef NativeOutputHandler = void Function(String line);

abstract interface class ProgramRunner {
  Future<List<String>> run(
    String executable, {
    InputRequestHandler? onInputRequest,
    NativeOutputHandler? onOutput,
  });
}
