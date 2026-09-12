// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_account.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deleteAccount)
final deleteAccountProvider = DeleteAccountProvider._();

final class DeleteAccountProvider
    extends $FunctionalProvider<DeleteAccount, DeleteAccount, DeleteAccount>
    with $Provider<DeleteAccount> {
  DeleteAccountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteAccountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteAccountHash();

  @$internal
  @override
  $ProviderElement<DeleteAccount> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeleteAccount create(Ref ref) {
    return deleteAccount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteAccount value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteAccount>(value),
    );
  }
}

String _$deleteAccountHash() => r'f1d7596c5953bfc989d444b46b43fd52962040ea';
