// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_playback_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Rendering checkpoint only. ACKs and confirmed recovery must use the fresh
/// active-session stream, never this retained value. A scope change discards it.

@ProviderFor(DisplayPlaybackSession)
final displayPlaybackSessionProvider = DisplayPlaybackSessionProvider._();

/// Rendering checkpoint only. ACKs and confirmed recovery must use the fresh
/// active-session stream, never this retained value. A scope change discards it.
final class DisplayPlaybackSessionProvider
    extends $NotifierProvider<DisplayPlaybackSession, PlaybackSession?> {
  /// Rendering checkpoint only. ACKs and confirmed recovery must use the fresh
  /// active-session stream, never this retained value. A scope change discards it.
  DisplayPlaybackSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayPlaybackSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayPlaybackSessionHash();

  @$internal
  @override
  DisplayPlaybackSession create() => DisplayPlaybackSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackSession?>(value),
    );
  }
}

String _$displayPlaybackSessionHash() =>
    r'ab6d4c1dc51309069afe44edcea93d93791e38dd';

/// Rendering checkpoint only. ACKs and confirmed recovery must use the fresh
/// active-session stream, never this retained value. A scope change discards it.

abstract class _$DisplayPlaybackSession extends $Notifier<PlaybackSession?> {
  PlaybackSession? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlaybackSession?, PlaybackSession?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlaybackSession?, PlaybackSession?>,
              PlaybackSession?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
