// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preparation_diagnostics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(preparationDiagnostics)
final preparationDiagnosticsProvider = PreparationDiagnosticsProvider._();

final class PreparationDiagnosticsProvider
    extends
        $FunctionalProvider<
          PreparationDiagnostics,
          PreparationDiagnostics,
          PreparationDiagnostics
        >
    with $Provider<PreparationDiagnostics> {
  PreparationDiagnosticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preparationDiagnosticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preparationDiagnosticsHash();

  @$internal
  @override
  $ProviderElement<PreparationDiagnostics> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreparationDiagnostics create(Ref ref) {
    return preparationDiagnostics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreparationDiagnostics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreparationDiagnostics>(value),
    );
  }
}

String _$preparationDiagnosticsHash() =>
    r'3a644bc664e1673190fb8b7b2b65ec8383ebdc77';
