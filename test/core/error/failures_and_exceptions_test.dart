import 'package:acsys360/core/error/exceptions.dart';
import 'package:acsys360/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exceptions preserve custom and default messages', () {
    expect(const ServerException().message, 'Server Exception');
    expect(
      const CacheException('cache unavailable').message,
      'cache unavailable',
    );
    expect(const FileSystemException().message, 'File System Exception');
  });

  test('failures render their type and message', () {
    expect(const ServerFailure().toString(), 'ServerFailure: Server Error');
    expect(const CacheFailure('offline').toString(), 'CacheFailure: offline');
    expect(const FileSystemFailure('').toString(), 'FileSystemFailure');
  });
}
