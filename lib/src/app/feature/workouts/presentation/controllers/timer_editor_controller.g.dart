// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TimerEditorController)
final timerEditorControllerProvider = TimerEditorControllerFamily._();

final class TimerEditorControllerProvider
    extends $NotifierProvider<TimerEditorController, TimerEditorState> {
  TimerEditorControllerProvider._({
    required TimerEditorControllerFamily super.from,
    required WorkoutModule super.argument,
  }) : super(
         retry: null,
         name: r'timerEditorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$timerEditorControllerHash();

  @override
  String toString() {
    return r'timerEditorControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TimerEditorController create() => TimerEditorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimerEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimerEditorState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TimerEditorControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timerEditorControllerHash() =>
    r'70079ad5ed1a45a085c5d7c7d08f75f4189b7f90';

final class TimerEditorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TimerEditorController,
          TimerEditorState,
          TimerEditorState,
          TimerEditorState,
          WorkoutModule
        > {
  TimerEditorControllerFamily._()
    : super(
        retry: null,
        name: r'timerEditorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TimerEditorControllerProvider call(WorkoutModule initial) =>
      TimerEditorControllerProvider._(argument: initial, from: this);

  @override
  String toString() => r'timerEditorControllerProvider';
}

abstract class _$TimerEditorController extends $Notifier<TimerEditorState> {
  late final _$args = ref.$arg as WorkoutModule;
  WorkoutModule get initial => _$args;

  TimerEditorState build(WorkoutModule initial);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TimerEditorState, TimerEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimerEditorState, TimerEditorState>,
              TimerEditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
