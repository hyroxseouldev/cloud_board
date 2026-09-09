// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_account_scope.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firebaseAccountUser)
final firebaseAccountUserProvider = FirebaseAccountUserProvider._();

final class FirebaseAccountUserProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  FirebaseAccountUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseAccountUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseAccountUserHash();

  @$internal
  @override
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return firebaseAccountUser(ref);
  }
}

String _$firebaseAccountUserHash() =>
    r'5702fc480324d6724f3ad6f47c05a663316c3838';

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

String _$accountOwnerIdHash() => r'9b53889b4c511b6d70023c45c8715ac967bbeada';
