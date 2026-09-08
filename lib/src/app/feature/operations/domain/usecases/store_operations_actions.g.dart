// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_operations_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storeOperationsActions)
final storeOperationsActionsProvider = StoreOperationsActionsProvider._();

final class StoreOperationsActionsProvider
    extends
        $FunctionalProvider<
          StoreOperationsActions,
          StoreOperationsActions,
          StoreOperationsActions
        >
    with $Provider<StoreOperationsActions> {
  StoreOperationsActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeOperationsActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeOperationsActionsHash();

  @$internal
  @override
  $ProviderElement<StoreOperationsActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StoreOperationsActions create(Ref ref) {
    return storeOperationsActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoreOperationsActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoreOperationsActions>(value),
    );
  }
}

String _$storeOperationsActionsHash() =>
    r'7a9afc82f3f41de0d1c31784192721c15bf41aa8';
