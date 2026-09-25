import '../../features/editor/data/datasources/compiler_process_factory.dart';
import '../../features/editor/data/datasources/local_workspace_path_service.dart';
import '../../features/editor/data/datasources/native_artifact_runner.dart';
import '../../features/editor/data/repositories_impl/local_workspace_repository_impl.dart';
import '../../features/editor/presentation/controllers/editor_controller.dart';

class ServiceLocator {
  ServiceLocator._();

  static EditorController createEditorController({String rootPath = ''}) {
    final repository = LocalWorkspaceRepository();
    final compiler = createCompilerRepository();
    return EditorController(
      repository: repository,
      compiler: compiler,
      assistant: compiler,
      pathService: const LocalWorkspacePathService(),
      artifactRunner: const NativeArtifactRunner(),
      rootPath: rootPath,
    );
  }
}
