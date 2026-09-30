// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountDeletionController)
final accountDeletionControllerProvider = AccountDeletionControllerProvider._();

final class AccountDeletionControllerProvider
    extends
        $NotifierProvider<
          AccountDeletionController,
          AsyncValue<AccountDeletionResult?>
        > {
  AccountDeletionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionControllerHash();

  @$internal
  @override
  AccountDeletionController create() => AccountDeletionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AccountDeletionResult?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AccountDeletionResult?>>(
        value,
      ),
    );
  }
}

String _$accountDeletionControllerHash() =>
    r'5e2affedcce958445f4b372e12f8338f626d30a6';

abstract class _$AccountDeletionController
    extends $Notifier<AsyncValue<AccountDeletionResult?>> {
  AsyncValue<AccountDeletionResult?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AccountDeletionResult?>,
              AsyncValue<AccountDeletionResult?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AccountDeletionResult?>,
                AsyncValue<AccountDeletionResult?>
              >,
              AsyncValue<AccountDeletionResult?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
