// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlement_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storeEntitlement)
final storeEntitlementProvider = StoreEntitlementProvider._();

final class StoreEntitlementProvider
    extends
        $FunctionalProvider<
          AsyncValue<StoreEntitlement?>,
          StoreEntitlement?,
          Stream<StoreEntitlement?>
        >
    with
        $FutureModifier<StoreEntitlement?>,
        $StreamProvider<StoreEntitlement?> {
  StoreEntitlementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeEntitlementProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeEntitlementHash();

  @$internal
  @override
  $StreamProviderElement<StoreEntitlement?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<StoreEntitlement?> create(Ref ref) {
    return storeEntitlement(ref);
  }
}

String _$storeEntitlementHash() => r'e308a42a91ec7c8efa5bd0303cb9cdb3f69ac451';

@ProviderFor(entitlementConnection)
final entitlementConnectionProvider = EntitlementConnectionProvider._();

final class EntitlementConnectionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  EntitlementConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementConnectionHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return entitlementConnection(ref);
  }
}

String _$entitlementConnectionHash() =>
    r'8e849b8641104eee9035896760768670218fc232';

@ProviderFor(storeAccountLink)
final storeAccountLinkProvider = StoreAccountLinkProvider._();

final class StoreAccountLinkProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  StoreAccountLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeAccountLinkProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeAccountLinkHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return storeAccountLink(ref);
  }
}

String _$storeAccountLinkHash() => r'96ace136cbcc60906645a5010382c1b827f58d50';
