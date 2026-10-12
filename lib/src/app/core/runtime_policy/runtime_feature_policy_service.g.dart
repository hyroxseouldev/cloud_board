// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_feature_policy_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(runtimeFeaturePolicyService)
final runtimeFeaturePolicyServiceProvider =
    RuntimeFeaturePolicyServiceProvider._();

final class RuntimeFeaturePolicyServiceProvider
    extends
        $FunctionalProvider<
          RuntimeFeaturePolicyService,
          RuntimeFeaturePolicyService,
          RuntimeFeaturePolicyService
        >
    with $Provider<RuntimeFeaturePolicyService> {
  RuntimeFeaturePolicyServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runtimeFeaturePolicyServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runtimeFeaturePolicyServiceHash();

  @$internal
  @override
  $ProviderElement<RuntimeFeaturePolicyService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RuntimeFeaturePolicyService create(Ref ref) {
    return runtimeFeaturePolicyService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RuntimeFeaturePolicyService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RuntimeFeaturePolicyService>(value),
    );
  }
}

String _$runtimeFeaturePolicyServiceHash() =>
    r'798ecd209f5ba50c3adc81430f8f6bb44e5d8797';
