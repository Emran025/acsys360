import 'package:flutter/material.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String editor = '/editor';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
      case AppRoutes.editor:
      default:
        return null;
    }
  }
}
