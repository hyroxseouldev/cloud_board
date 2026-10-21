// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playerClock)
final playerClockProvider = PlayerClockProvider._();

final class PlayerClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  PlayerClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return playerClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$playerClockHash() => r'447f09b8ea5bea395c948aa7b162abf3544cd84f';

/// Remember only the last displayed class across player/widget disposal. This
/// is an audio marker, not a playback checkpoint or permission to keep playing.

@ProviderFor(displayAudioAttachment)
final displayAudioAttachmentProvider = DisplayAudioAttachmentProvider._();

/// Remember only the last displayed class across player/widget disposal. This
/// is an audio marker, not a playback checkpoint or permission to keep playing.

final class DisplayAudioAttachmentProvider
    extends
        $FunctionalProvider<
          DisplayAudioAttachment,
          DisplayAudioAttachment,
          DisplayAudioAttachment
        >
    with $Provider<DisplayAudioAttachment> {
  /// Remember only the last displayed class across player/widget disposal. This
  /// is an audio marker, not a playback checkpoint or permission to keep playing.
  DisplayAudioAttachmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayAudioAttachmentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayAudioAttachmentHash();

  @$internal
  @override
  $ProviderElement<DisplayAudioAttachment> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisplayAudioAttachment create(Ref ref) {
    return displayAudioAttachment(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayAudioAttachment value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayAudioAttachment>(value),
    );
  }
}

String _$displayAudioAttachmentHash() =>
    r'5a41d1633c6b96e27c9dd5bd8999abcf916d9563';

@ProviderFor(PlayerController)
final playerControllerProvider = PlayerControllerFamily._();

final class PlayerControllerProvider
    extends $NotifierProvider<PlayerController, PlayerState> {
  PlayerControllerProvider._({
    required PlayerControllerFamily super.from,
    required (Workout, {int startModule, String? sessionId, bool canControl})
    super.argument,
  }) : super(
         retry: null,
         name: r'playerControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$playerControllerHash();

  @override
  String toString() {
    return r'playerControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  PlayerController create() => PlayerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$playerControllerHash() => r'61560f68ce60f3efcde38ac0462dc6aae573aa48';

final class PlayerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PlayerController,
          PlayerState,
          PlayerState,
          PlayerState,
          (Workout, {int startModule, String? sessionId, bool canControl})
        > {
  PlayerControllerFamily._()
    : super(
        retry: null,
        name: r'playerControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PlayerControllerProvider call(
    Workout workout, {
    int startModule = 0,
    String? sessionId,
    bool canControl = true,
  }) => PlayerControllerProvider._(
    argument: (
      workout,
      startModule: startModule,
      sessionId: sessionId,
      canControl: canControl,
    ),
    from: this,
  );

  @override
  String toString() => r'playerControllerProvider';
}

abstract class _$PlayerController extends $Notifier<PlayerState> {
  late final _$args =
      ref.$arg
          as (Workout, {int startModule, String? sessionId, bool canControl});
  Workout get workout => _$args.$1;
  int get startModule => _$args.startModule;
  String? get sessionId => _$args.sessionId;
  bool get canControl => _$args.canControl;

  PlayerState build(
    Workout workout, {
    int startModule = 0,
    String? sessionId,
    bool canControl = true,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlayerState, PlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerState, PlayerState>,
              PlayerState,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        _$args.$1,
        startModule: _$args.startModule,
        sessionId: _$args.sessionId,
        canControl: _$args.canControl,
      ),
    );
  }
}
