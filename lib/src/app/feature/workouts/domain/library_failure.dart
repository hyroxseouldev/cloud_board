class LibraryFailure implements Exception {
  const LibraryFailure(this.message, {this.cause});
  final Object? cause;
  final String message;
  @override
  String toString() => message;
}
