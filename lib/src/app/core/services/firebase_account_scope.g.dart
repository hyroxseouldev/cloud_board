// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_account_scope.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firebaseClientAuth)
final firebaseClientAuthProvider = FirebaseClientAuthProvider._();

final class FirebaseClientAuthProvider
    extends $FunctionalProvider<FirebaseAuth, FirebaseAuth, FirebaseAuth>
    with $Provider<FirebaseAuth> {
  FirebaseClientAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseClientAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseClientAuthHash();

  @$internal
  @override
  $ProviderElement<FirebaseAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseAuth create(Ref ref) {
    return firebaseClientAuth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseAuth>(value),
    );
  }
}

String _$firebaseClientAuthHash() =>
    r'7bef90521fa9031e0e363e5727e502bc2c36ccae';

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
    r'471ea6d6328cc97430503f4d24870b4ca637d3b1';

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

String _$accountOwnerIdHash() => r'9da9d42cf56a2f44f4a5e49d6c801781a44ed9a6';
