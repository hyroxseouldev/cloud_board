// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_session_local_data_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackSessionLocalDataSource)
final playbackSessionLocalDataSourceProvider =
    PlaybackSessionLocalDataSourceProvider._();

final class PlaybackSessionLocalDataSourceProvider
    extends
        $FunctionalProvider<
          PlaybackSessionLocalDataSource,
          PlaybackSessionLocalDataSource,
          PlaybackSessionLocalDataSource
        >
    with $Provider<PlaybackSessionLocalDataSource> {
  PlaybackSessionLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackSessionLocalDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackSessionLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<PlaybackSessionLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaybackSessionLocalDataSource create(Ref ref) {
    return playbackSessionLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackSessionLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackSessionLocalDataSource>(
        value,
      ),
    );
  }
}

String _$playbackSessionLocalDataSourceHash() =>
    r'cd783a6654fcf063683bb56f1f4453b23c993c9b';
