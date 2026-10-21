// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_raster_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiRasterActions)
final aiRasterActionsProvider = AiRasterActionsProvider._();

final class AiRasterActionsProvider
    extends
        $FunctionalProvider<AiRasterActions, AiRasterActions, AiRasterActions>
    with $Provider<AiRasterActions> {
  AiRasterActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiRasterActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiRasterActionsHash();

  @$internal
  @override
  $ProviderElement<AiRasterActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiRasterActions create(Ref ref) {
    return aiRasterActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiRasterActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiRasterActions>(value),
    );
  }
}

String _$aiRasterActionsHash() => r'fb5a941ec8f5611d9a6f0e4965c31d082065eab0';
