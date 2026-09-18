// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entitlement_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(entitlementRepository)
final entitlementRepositoryProvider = EntitlementRepositoryProvider._();

final class EntitlementRepositoryProvider
    extends
        $FunctionalProvider<
          EntitlementRepository,
          EntitlementRepository,
          EntitlementRepository
        >
    with $Provider<EntitlementRepository> {
  EntitlementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementRepositoryHash();

  @$internal
  @override
  $ProviderElement<EntitlementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementRepository create(Ref ref) {
    return entitlementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementRepository>(value),
    );
  }
}

String _$entitlementRepositoryHash() =>
    r'e4c80f44a4b0359fc16ad89c3c5d3be5fd5ecea1';
