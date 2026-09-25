import 'package:flutter/material.dart';

import '../features/editor/domain/services/document_file_service.dart';
import '../features/editor/presentation/controllers/editor_controller.dart';
import '../features/editor/presentation/ui/screens/editor_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String editor = '/editor';
}

/// Central route factory for the desktop editor shell.
///
/// The controller remains injected by the application composition root so the
/// route layer only selects presentation destinations and never creates data
/// dependencies.
class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    required EditorController controller,
    DocumentFileService fileService = const UnavailableDocumentFileService(),
    VoidCallback? onToggleTheme,
    bool isDark = false,
  }) {
    switch (settings.name) {
      case AppRoutes.home:
      case AppRoutes.editor:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => EditorShell(
            controller: controller,
            fileService: fileService,
            onToggleTheme: onToggleTheme,
            isDark: isDark,
          ),
        );
      default:
        return null;
    }
  }
}
