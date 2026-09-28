// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(billingStatus)
final billingStatusProvider = BillingStatusProvider._();

final class BillingStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<BillingStatus>,
          BillingStatus,
          FutureOr<BillingStatus>
        >
    with $FutureModifier<BillingStatus>, $FutureProvider<BillingStatus> {
  BillingStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingStatusHash();

  @$internal
  @override
  $FutureProviderElement<BillingStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BillingStatus> create(Ref ref) {
    return billingStatus(ref);
  }
}

String _$billingStatusHash() => r'5b334c337b6d1dfb6d79be8ef4562f6020cb109a';

@ProviderFor(billingOffers)
final billingOffersProvider = BillingOffersProvider._();

final class BillingOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BillingOffer>>,
          List<BillingOffer>,
          FutureOr<List<BillingOffer>>
        >
    with
        $FutureModifier<List<BillingOffer>>,
        $FutureProvider<List<BillingOffer>> {
  BillingOffersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingOffersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingOffersHash();

  @$internal
  @override
  $FutureProviderElement<List<BillingOffer>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BillingOffer>> create(Ref ref) {
    return billingOffers(ref);
  }
}

String _$billingOffersHash() => r'1f3d1d56e67be496042283cfc78502bbf15f2b0c';

@ProviderFor(BillingPurchaseController)
final billingPurchaseControllerProvider = BillingPurchaseControllerProvider._();

final class BillingPurchaseControllerProvider
    extends $NotifierProvider<BillingPurchaseController, BillingActivity> {
  BillingPurchaseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingPurchaseControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingPurchaseControllerHash();

  @$internal
  @override
  BillingPurchaseController create() => BillingPurchaseController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BillingActivity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BillingActivity>(value),
    );
  }
}

String _$billingPurchaseControllerHash() =>
    r'a0d3e9ac28e6a84e203e822847ad3c392451fe8e';

abstract class _$BillingPurchaseController extends $Notifier<BillingActivity> {
  BillingActivity build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BillingActivity, BillingActivity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BillingActivity, BillingActivity>,
              BillingActivity,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
