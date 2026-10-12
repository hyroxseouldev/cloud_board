// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_recovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutRecoveryController)
final workoutRecoveryControllerProvider = WorkoutRecoveryControllerFamily._();

final class WorkoutRecoveryControllerProvider
    extends $NotifierProvider<WorkoutRecoveryController, WorkoutRecoveryState> {
  WorkoutRecoveryControllerProvider._({
    required WorkoutRecoveryControllerFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'workoutRecoveryControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutRecoveryControllerHash();

  @override
  String toString() {
    return r'workoutRecoveryControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  WorkoutRecoveryController create() => WorkoutRecoveryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutRecoveryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutRecoveryState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutRecoveryControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutRecoveryControllerHash() =>
    r'566ebb726848b5af1c7a8889cda2b8d0b40340cb';

final class WorkoutRecoveryControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkoutRecoveryController,
          WorkoutRecoveryState,
          WorkoutRecoveryState,
          WorkoutRecoveryState,
          (String, String)
        > {
  WorkoutRecoveryControllerFamily._()
    : super(
        retry: null,
        name: r'workoutRecoveryControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkoutRecoveryControllerProvider call(String ownerId, String slot) =>
      WorkoutRecoveryControllerProvider._(
        argument: (ownerId, slot),
        from: this,
      );

  @override
  String toString() => r'workoutRecoveryControllerProvider';
}

abstract class _$WorkoutRecoveryController
    extends $Notifier<WorkoutRecoveryState> {
  late final _$args = ref.$arg as (String, String);
  String get ownerId => _$args.$1;
  String get slot => _$args.$2;

  WorkoutRecoveryState build(String ownerId, String slot);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorkoutRecoveryState, WorkoutRecoveryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorkoutRecoveryState, WorkoutRecoveryState>,
              WorkoutRecoveryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
