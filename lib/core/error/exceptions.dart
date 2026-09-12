class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server Exception']);
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache Exception']);
}

class FileSystemException implements Exception {
  final String message;
  const FileSystemException([this.message = 'File System Exception']);
}
