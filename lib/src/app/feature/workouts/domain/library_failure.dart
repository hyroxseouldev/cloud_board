class LibraryFailure implements Exception {
  const LibraryFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
