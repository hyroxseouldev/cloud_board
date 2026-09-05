// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getUserProfile)
final getUserProfileProvider = GetUserProfileProvider._();

final class GetUserProfileProvider
    extends $FunctionalProvider<GetUserProfile, GetUserProfile, GetUserProfile>
    with $Provider<GetUserProfile> {
  GetUserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getUserProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getUserProfileHash();

  @$internal
  @override
  $ProviderElement<GetUserProfile> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetUserProfile create(Ref ref) {
    return getUserProfile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetUserProfile value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetUserProfile>(value),
    );
  }
}

String _$getUserProfileHash() => r'a867ba3c4d5acc77f7c42f8cc4fa0d41e8c20b0a';

@ProviderFor(updateUserProfile)
final updateUserProfileProvider = UpdateUserProfileProvider._();

final class UpdateUserProfileProvider
    extends
        $FunctionalProvider<
          UpdateUserProfile,
          UpdateUserProfile,
          UpdateUserProfile
        >
    with $Provider<UpdateUserProfile> {
  UpdateUserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateUserProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateUserProfileHash();

  @$internal
  @override
  $ProviderElement<UpdateUserProfile> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateUserProfile create(Ref ref) {
    return updateUserProfile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateUserProfile value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateUserProfile>(value),
    );
  }
}

String _$updateUserProfileHash() => r'9b993ea15c6b76eb4cf551706fa3cfeb3c303219';
