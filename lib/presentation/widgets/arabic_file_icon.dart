import 'package:flutter/material.dart';

class ArabicFileIcon extends StatelessWidget {
  final String path;
  final IconData fallback;
  final double size;
  final Color? color;

  const ArabicFileIcon({
    super.key,
    required this.path,
    required this.fallback,
    this.size = 18,
    this.color,
  });

  bool get _isArabicSource => path.toLowerCase().endsWith('.arb');

  @override
  Widget build(BuildContext context) {
    if (_isArabicSource) {
      return Image.asset(
        'assets/branding/arabic360.png',
        key: const ValueKey('arabic-file-icon'),
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Icon(fallback, size: size, color: color);
  }
}
