import 'package:acsys360/domain/services/workspace_path_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = DefaultWorkspacePathService();

  test('handles POSIX workspace paths', () {
    expect(service.baseName('/workspace/src/main.arb'), 'main.arb');
    expect(
      service.parentOf('/workspace/src/main.arb', fallback: '/workspace'),
      '/workspace/src',
    );
    expect(
      service.join('/workspace/src', 'main.arb'),
      '/workspace/src/main.arb',
    );
    expect(
      service.isSameOrDescendant('/workspace/src/main.arb', '/workspace/src'),
      isTrue,
    );
  });

  test('handles Windows-style workspace paths without dart:io', () {
    expect(service.baseName(r'C:\workspace\main.arb'), 'main.arb');
    expect(
      service.parentOf(r'C:\workspace\main.arb', fallback: r'C:\workspace'),
      r'C:\workspace',
    );
    expect(service.join(r'C:\workspace', 'main.arb'), r'C:\workspace\main.arb');
    expect(
      service.relocate(
        r'C:\workspace\src\main.arb',
        source: r'C:\workspace\src',
        target: r'C:\workspace\lib',
      ),
      r'C:\workspace\lib\main.arb',
    );
  });
}
