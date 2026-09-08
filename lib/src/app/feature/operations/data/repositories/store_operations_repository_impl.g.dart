// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_operations_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storeOperationsRepository)
final storeOperationsRepositoryProvider = StoreOperationsRepositoryProvider._();

final class StoreOperationsRepositoryProvider
    extends
        $FunctionalProvider<
          StoreOperationsRepository,
          StoreOperationsRepository,
          StoreOperationsRepository
        >
    with $Provider<StoreOperationsRepository> {
  StoreOperationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeOperationsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeOperationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<StoreOperationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StoreOperationsRepository create(Ref ref) {
    return storeOperationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoreOperationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoreOperationsRepository>(value),
    );
  }
}

String _$storeOperationsRepositoryHash() =>
    r'4072afa1312cc9e5187fd139f258aeb4ac8f6365';
