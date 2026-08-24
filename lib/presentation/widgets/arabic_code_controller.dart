import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ArabicCodeController extends TextEditingController {
  static final _tokenPattern = RegExp(
    r'"(?:\\.|[^"\\])*"|[0-9]+|[ء-ي]+|[A-Za-z_][A-Za-z0-9_]*',
  );
  static const _keywords = {
    'برنامج',
    'دالة',
    'متغير',
    'اذا',
    'وإلا',
    'طالما',
    'لكل',
    'ارجع',
    'اطبع',
    'صحيح',
    'خطأ',
    'نص',
    'عدد',
  };

  ArabicCodeController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final colors = Theme.of(context).colorScheme;
    final children = <TextSpan>[];
    var cursor = 0;
    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final color = token.startsWith('"')
          ? colors.tertiary
          : int.tryParse(token) != null
          ? colors.secondary
          : _keywords.contains(token)
          ? AppTheme.brandOrange
          : null;
      children.add(
        TextSpan(
          text: token,
          style: color == null ? null : baseStyle.copyWith(color: color),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: children);
  }
}
