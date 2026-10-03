import 'dart:io';

import 'package:acsys360/features/editor/data/datasources/local_workspace_path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = LocalWorkspacePathService();
  final separator = Platform.pathSeparator;

  test('handles roots, trailing separators, and joins', () {
    expect(service.parentOf(separator, fallback: '/fallback'), '/fallback');
    expect(service.parentOf('main.arb', fallback: '/fallback'), '/fallback');
    expect(service.baseName('/workspace$separator'), 'workspace');
    expect(
      service.join('/workspace$separator', 'main.arb'),
      '/workspace${separator}main.arb',
    );
  });

  test(
    'recognizes descendants and relocates only within the source subtree',
    () {
      final root = '/workspace';
      expect(service.isSameOrDescendant(root, root), isTrue);
      expect(service.isSameOrDescendant('$root${separator}src', root), isTrue);
      expect(service.isSameOrDescendant('/other', root), isFalse);
      expect(
        service.relocate(
          '$root${separator}src${separator}main.arb',
          source: '$root${separator}src',
          target: '$root${separator}lib',
        ),
        '$root${separator}lib${separator}main.arb',
      );
      expect(
        service.relocate(
          '/other/main.arb',
          source: '$root/src',
          target: '$root/lib',
        ),
        '/other/main.arb',
      );
    },
  );
}
