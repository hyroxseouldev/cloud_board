// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_recovery_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displayRecoveryRepository)
final displayRecoveryRepositoryProvider = DisplayRecoveryRepositoryProvider._();

final class DisplayRecoveryRepositoryProvider
    extends
        $FunctionalProvider<
          DisplayRecoveryRepository,
          DisplayRecoveryRepository,
          DisplayRecoveryRepository
        >
    with $Provider<DisplayRecoveryRepository> {
  DisplayRecoveryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayRecoveryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayRecoveryRepositoryHash();

  @$internal
  @override
  $ProviderElement<DisplayRecoveryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisplayRecoveryRepository create(Ref ref) {
    return displayRecoveryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayRecoveryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayRecoveryRepository>(value),
    );
  }
}

String _$displayRecoveryRepositoryHash() =>
    r'063c68c47fc5761ee8e6f2bcd8333ea9d45db510';
