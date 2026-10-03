import 'package:acsys360/features/editor/domain/services/source_file_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = SourceFilePolicy();

  test('accepts the Arabic source extension case-insensitively', () {
    expect(policy.accepts('main.arb'), isTrue);
    expect(policy.accepts('MAIN.ARB'), isTrue);
    expect(policy.accepts('main.dart'), isFalse);
  });

  test('adds the extension only when it is absent', () {
    expect(policy.ensureExtension('main'), 'main.arb');
    expect(policy.ensureExtension('main.ARB'), 'main.ARB');
  });
}
