// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_telemetry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(operationTelemetry)
final operationTelemetryProvider = OperationTelemetryProvider._();

final class OperationTelemetryProvider
    extends
        $FunctionalProvider<
          OperationTelemetry,
          OperationTelemetry,
          OperationTelemetry
        >
    with $Provider<OperationTelemetry> {
  OperationTelemetryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationTelemetryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationTelemetryHash();

  @$internal
  @override
  $ProviderElement<OperationTelemetry> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OperationTelemetry create(Ref ref) {
    return operationTelemetry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OperationTelemetry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OperationTelemetry>(value),
    );
  }
}

String _$operationTelemetryHash() =>
    r'6919fdd4981a27676891e480494c225b094ceeab';
