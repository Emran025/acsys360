import 'package:flutter/material.dart';

import 'config/di/injection.dart';
import 'features/editor/domain/services/document_file_service.dart';
import 'features/editor/presentation/controllers/editor_controller.dart';
import 'routes/app_router.dart';
import 'shared/themes/app_theme.dart';

export 'features/editor/presentation/ui/screens/editor_screen.dart';
export 'features/editor/presentation/ui/widgets/editor_intents.dart';

void main() {
  runApp(
    ArabicEditorApp(
      controller: ServiceLocator.createEditorController(),
      fileService: ServiceLocator.createDocumentFileService(),
    ),
  );
}

class ArabicEditorApp extends StatefulWidget {
  final EditorController controller;
  final DocumentFileService fileService;

  const ArabicEditorApp({
    super.key,
    required this.controller,
    this.fileService = const UnavailableDocumentFileService(),
  });

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
        fileService: widget.fileService,
        onToggleTheme: _toggleTheme,
        isDark: themeMode == ThemeMode.dark,
      ),
    ),
  );
}
