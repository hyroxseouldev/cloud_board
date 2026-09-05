// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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

String _$playerControllerHash() => r'f16d33cc6bf64e1c2324db9943a7d22d65c5be51';

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
