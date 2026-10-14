import 'dart:async';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';

/// Bounded, serialized preparation retries. Identity/foreground cancellation is
/// checked before every attempt and after every await, including the backoff.
Future<T?> retryDisplayPreparation<T>({
  required Future<T> Function() operation,
  required bool Function() cancelled,
  required void Function(String code, int attempt) onFailure,
  Future<void> Function(Duration)? delay,
  int maxAttempts = 4,
}) async {
  final wait = delay ?? Future<void>.delayed;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (cancelled()) return null;
    try {
      final value = await operation();
      return cancelled() ? null : value;
    } catch (error) {
      if (cancelled()) return null;
      final code = operationFailureCode(error);
      onFailure(code, attempt);
      if (code == 'permission-denied' ||
          code == 'unauthenticated' ||
          attempt == maxAttempts) {
        return null;
      }
      await wait(Duration(seconds: 1 << (attempt - 1)));
    }
  }
  return null;
}
