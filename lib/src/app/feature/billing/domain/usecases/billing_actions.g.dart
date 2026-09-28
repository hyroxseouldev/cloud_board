// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(billingActions)
final billingActionsProvider = BillingActionsProvider._();

final class BillingActionsProvider
    extends $FunctionalProvider<BillingActions, BillingActions, BillingActions>
    with $Provider<BillingActions> {
  BillingActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billingActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billingActionsHash();

  @$internal
  @override
  $ProviderElement<BillingActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BillingActions create(Ref ref) {
    return billingActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BillingActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BillingActions>(value),
    );
  }
}

String _$billingActionsHash() => r'0e920efaebe5d71a184d0f8e1925843ad4abd7ad';
