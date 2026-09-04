// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_auth_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firebaseAuthDataSource)
final firebaseAuthDataSourceProvider = FirebaseAuthDataSourceProvider._();

final class FirebaseAuthDataSourceProvider
    extends
        $FunctionalProvider<
          FirebaseAuthDataSource,
          FirebaseAuthDataSource,
          FirebaseAuthDataSource
        >
    with $Provider<FirebaseAuthDataSource> {
  FirebaseAuthDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseAuthDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseAuthDataSourceHash();

  @$internal
  @override
  $ProviderElement<FirebaseAuthDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FirebaseAuthDataSource create(Ref ref) {
    return firebaseAuthDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseAuthDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseAuthDataSource>(value),
    );
  }
}

String _$firebaseAuthDataSourceHash() =>
    r'02330452ce60d4b6f9c98e30fc3bc7d860bc804c';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'30f0fe76edab21297ce65df0cf5d26afdc8e2dcf';
