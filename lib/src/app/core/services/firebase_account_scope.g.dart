// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_account_scope.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountOwnerId)
final accountOwnerIdProvider = AccountOwnerIdProvider._();

final class AccountOwnerIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  AccountOwnerIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountOwnerIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountOwnerIdHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return accountOwnerId(ref);
  }
}

String _$accountOwnerIdHash() => r'37d6425e843ab46dd59b2525bb6f1d853a61a460';
