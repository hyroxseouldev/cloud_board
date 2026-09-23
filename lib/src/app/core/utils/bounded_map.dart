/// Preserves order, drains active work on failure, and never starts more than
/// [concurrency] tasks at once. A failed batch cannot keep uploading in the background.
Future<List<R>> boundedMap<T, R>(
  List<T> items,
  Future<R> Function(T) action, {
  int concurrency = 3,
}) async {
  if (concurrency < 1) throw ArgumentError.value(concurrency);
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Object? failure;
  StackTrace? failureStack;
  Future<void> worker() async {
    while (failure == null && next < items.length) {
      final index = next++;
      try {
        results[index] = await action(items[index]);
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }
  }

  await Future.wait(
    List.generate(
      items.length < concurrency ? items.length : concurrency,
      (_) => worker(),
    ),
  );
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return results.cast<R>();
}
