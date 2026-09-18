// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlement_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(entitlementActions)
final entitlementActionsProvider = EntitlementActionsProvider._();

final class EntitlementActionsProvider
    extends
        $FunctionalProvider<
          EntitlementActions,
          EntitlementActions,
          EntitlementActions
        >
    with $Provider<EntitlementActions> {
  EntitlementActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementActionsHash();

  @$internal
  @override
  $ProviderElement<EntitlementActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementActions create(Ref ref) {
    return entitlementActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementActions>(value),
    );
  }
}

String _$entitlementActionsHash() =>
    r'5218aa0ae87bc90f00b882d995fee8aa84dd0ae6';
