// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_list_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutListModeSelectorEnabled)
final workoutListModeSelectorEnabledProvider =
    WorkoutListModeSelectorEnabledProvider._();

final class WorkoutListModeSelectorEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  WorkoutListModeSelectorEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutListModeSelectorEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutListModeSelectorEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return workoutListModeSelectorEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$workoutListModeSelectorEnabledHash() =>
    r'0c3e1f20ba4a4a0784079d387579a93b4ff05d7c';

@ProviderFor(WorkoutListModeController)
final workoutListModeControllerProvider = WorkoutListModeControllerProvider._();

final class WorkoutListModeControllerProvider
    extends $NotifierProvider<WorkoutListModeController, WorkoutListMode> {
  WorkoutListModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutListModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutListModeControllerHash();

  @$internal
  @override
  WorkoutListModeController create() => WorkoutListModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutListMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutListMode>(value),
    );
  }
}

String _$workoutListModeControllerHash() =>
    r'4dd57e983aff2f1674ef331134e0950844c4fa02';

abstract class _$WorkoutListModeController extends $Notifier<WorkoutListMode> {
  WorkoutListMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorkoutListMode, WorkoutListMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorkoutListMode, WorkoutListMode>,
              WorkoutListMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
