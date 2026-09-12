abstract class Failure {
  final String message;
  const Failure([this.message = '']);

  @override
  String toString() => message.isEmpty ? runtimeType.toString() : '$runtimeType: $message';
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server Error']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache Error']);
}

class FileSystemFailure extends Failure {
  const FileSystemFailure([super.message = 'File System Error']);
}
