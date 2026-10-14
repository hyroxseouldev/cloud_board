// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_event_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
    r'05b9f22f183e5e4635ca2ed71be9052dee093e14';
