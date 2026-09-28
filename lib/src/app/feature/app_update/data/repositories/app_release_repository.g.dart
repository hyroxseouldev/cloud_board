// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_release_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appReleaseRepository)
final appReleaseRepositoryProvider = AppReleaseRepositoryProvider._();

final class AppReleaseRepositoryProvider
    extends
        $FunctionalProvider<
          AppReleaseRepository,
          AppReleaseRepository,
          AppReleaseRepository
        >
    with $Provider<AppReleaseRepository> {
  AppReleaseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appReleaseRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appReleaseRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppReleaseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppReleaseRepository create(Ref ref) {
    return appReleaseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppReleaseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppReleaseRepository>(value),
    );
  }
}

String _$appReleaseRepositoryHash() =>
    r'9a37721b81aac33839a140ac711f78a8d7d5c7f4';
