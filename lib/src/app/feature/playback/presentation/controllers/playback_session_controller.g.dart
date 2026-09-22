// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activePlaybackSession)
final activePlaybackSessionProvider = ActivePlaybackSessionProvider._();

final class ActivePlaybackSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlaybackSession?>,
          PlaybackSession?,
          Stream<PlaybackSession?>
        >
    with $FutureModifier<PlaybackSession?>, $StreamProvider<PlaybackSession?> {
  ActivePlaybackSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activePlaybackSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activePlaybackSessionHash();

  @$internal
  @override
  $StreamProviderElement<PlaybackSession?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlaybackSession?> create(Ref ref) {
    return activePlaybackSession(ref);
  }
}

String _$activePlaybackSessionHash() =>
    r'50b7456a76e0a3005e7cc53337d64ddd3904a9b1';

@ProviderFor(serverTimeOffset)
final serverTimeOffsetProvider = ServerTimeOffsetProvider._();

final class ServerTimeOffsetProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  ServerTimeOffsetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverTimeOffsetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverTimeOffsetHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return serverTimeOffset(ref);
  }
}

String _$serverTimeOffsetHash() => r'1d0fdef9a8a0c3bfb484ff15e416c10d07adf176';

@ProviderFor(playbackConnection)
final playbackConnectionProvider = PlaybackConnectionProvider._();

final class PlaybackConnectionProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  PlaybackConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackConnectionHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return playbackConnection(ref);
  }
}

String _$playbackConnectionHash() =>
    r'bdf2d25f2758e140bb88121bee9e7809a08eb874';

@ProviderFor(PlaybackActionController)
final playbackActionControllerProvider = PlaybackActionControllerProvider._();

final class PlaybackActionControllerProvider
    extends $NotifierProvider<PlaybackActionController, AsyncValue<String?>> {
  PlaybackActionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackActionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackActionControllerHash();

  @$internal
  @override
  PlaybackActionController create() => PlaybackActionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String?>>(value),
    );
  }
}

String _$playbackActionControllerHash() =>
    r'9b7bf24a705bf4fd3e0b883e6f58972e4b9b1f98';

abstract class _$PlaybackActionController
    extends $Notifier<AsyncValue<String?>> {
  AsyncValue<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, AsyncValue<String?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, AsyncValue<String?>>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Blocks controller commands until a foreground server handshake completes.

@ProviderFor(PlaybackRecoveryController)
final playbackRecoveryControllerProvider =
    PlaybackRecoveryControllerProvider._();

/// Blocks controller commands until a foreground server handshake completes.
final class PlaybackRecoveryControllerProvider
    extends $NotifierProvider<PlaybackRecoveryController, AsyncValue<void>> {
  /// Blocks controller commands until a foreground server handshake completes.
  PlaybackRecoveryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackRecoveryControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackRecoveryControllerHash();

  @$internal
  @override
  PlaybackRecoveryController create() => PlaybackRecoveryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$playbackRecoveryControllerHash() =>
    r'3ede6b4ad71ec1a244bd0640b7f66c41aec005fc';

/// Blocks controller commands until a foreground server handshake completes.

abstract class _$PlaybackRecoveryController
    extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
