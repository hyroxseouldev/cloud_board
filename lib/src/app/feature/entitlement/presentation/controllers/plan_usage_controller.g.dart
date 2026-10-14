// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_usage_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(planUsageRepository)
final planUsageRepositoryProvider = PlanUsageRepositoryProvider._();

final class PlanUsageRepositoryProvider
    extends
        $FunctionalProvider<
          PlanUsageRepository,
          PlanUsageRepository,
          PlanUsageRepository
        >
    with $Provider<PlanUsageRepository> {
  PlanUsageRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planUsageRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planUsageRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlanUsageRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlanUsageRepository create(Ref ref) {
    return planUsageRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanUsageRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanUsageRepository>(value),
    );
  }
}

String _$planUsageRepositoryHash() =>
    r'49adab06f47c3940c3b14e53a416eab00a7251d6';

@ProviderFor(planUsage)
final planUsageProvider = PlanUsageProvider._();

final class PlanUsageProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlanUsage?>,
          PlanUsage?,
          Stream<PlanUsage?>
        >
    with $FutureModifier<PlanUsage?>, $StreamProvider<PlanUsage?> {
  PlanUsageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planUsageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planUsageHash();

  @$internal
  @override
  $StreamProviderElement<PlanUsage?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<PlanUsage?> create(Ref ref) {
    return planUsage(ref);
  }
}

String _$planUsageHash() => r'd69f0581e72bdd147044c302349a0cf8ab942495';
