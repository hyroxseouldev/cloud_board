// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackRepository)
final playbackRepositoryProvider = PlaybackRepositoryProvider._();

final class PlaybackRepositoryProvider
    extends
        $FunctionalProvider<
          PlaybackRepository,
          PlaybackRepository,
          PlaybackRepository
        >
    with $Provider<PlaybackRepository> {
  PlaybackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlaybackRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaybackRepository create(Ref ref) {
    return playbackRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackRepository>(value),
    );
  }
}

String _$playbackRepositoryHash() =>
    r'634f5a4494fdc5c5d1ce3d0fc3b550b9337e30fd';
