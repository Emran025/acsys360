import 'package:flutter/material.dart';

import 'features/editor/data/datasources/compiler_process_factory.dart';
import 'features/editor/data/datasources/local_workspace_path_service.dart';
import 'features/editor/data/repositories_impl/local_workspace_repository_impl.dart';
import 'features/editor/presentation/controllers/editor_controller.dart';
import 'routes/app_router.dart';
import 'shared/themes/app_theme.dart';

export 'features/editor/presentation/ui/screens/editor_screen.dart';
export 'features/editor/presentation/ui/widgets/editor_intents.dart';

void main() {
  final repository = LocalWorkspaceRepository();
  final compiler = createCompilerRepository();
  runApp(
    ArabicEditorApp(
      controller: EditorController(
        repository: repository,
        compiler: compiler,
        assistant: compiler,
        pathService: const LocalWorkspacePathService(),
        rootPath: '',
      ),
    ),
  );
}

class ArabicEditorApp extends StatefulWidget {
  final EditorController controller;

  const ArabicEditorApp({super.key, required this.controller});

  @override
  State<ArabicEditorApp> createState() => _ArabicEditorAppState();
}

class _ArabicEditorAppState extends State<ArabicEditorApp> {
  ThemeMode themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      themeMode = themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'محرر اللغة العربية',
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: AppRoutes.editor,
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(
        settings,
        controller: widget.controller,
        onToggleTheme: _toggleTheme,
        isDark: themeMode == ThemeMode.dark,
      ),
    ),
  );
}
