// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_event_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reuse the bounded diagnostics outbox, but send the original operation model
/// to its existing RTDB path. One queue survives identity changes so writes from
/// an old scope cannot race a new scope's local persistence.

@ProviderFor(operationEventQueue)
final operationEventQueueProvider = OperationEventQueueProvider._();

/// Reuse the bounded diagnostics outbox, but send the original operation model
/// to its existing RTDB path. One queue survives identity changes so writes from
/// an old scope cannot race a new scope's local persistence.

final class OperationEventQueueProvider
    extends
        $FunctionalProvider<DiagnosticQueue, DiagnosticQueue, DiagnosticQueue>
    with $Provider<DiagnosticQueue> {
  /// Reuse the bounded diagnostics outbox, but send the original operation model
  /// to its existing RTDB path. One queue survives identity changes so writes from
  /// an old scope cannot race a new scope's local persistence.
  OperationEventQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationEventQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationEventQueueHash();

  @$internal
  @override
  $ProviderElement<DiagnosticQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiagnosticQueue create(Ref ref) {
    return operationEventQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiagnosticQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiagnosticQueue>(value),
    );
  }
}

String _$operationEventQueueHash() =>
    r'32f095182f6923003fb3ff86166b258633093b41';

@ProviderFor(operationEventWriter)
final operationEventWriterProvider = OperationEventWriterProvider._();

final class OperationEventWriterProvider
    extends
        $FunctionalProvider<
          OperationEventWriter,
          OperationEventWriter,
          OperationEventWriter
        >
    with $Provider<OperationEventWriter> {
  OperationEventWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationEventWriterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationEventWriterHash();

  @$internal
  @override
  $ProviderElement<OperationEventWriter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OperationEventWriter create(Ref ref) {
    return operationEventWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OperationEventWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OperationEventWriter>(value),
    );
  }
}

String _$operationEventWriterHash() =>
    r'ce299b14f6fb2505172119585cf4216e5984a3be';
