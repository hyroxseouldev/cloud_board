// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutController)
final workoutControllerProvider = WorkoutControllerProvider._();

final class WorkoutControllerProvider
    extends $AsyncNotifierProvider<WorkoutController, List<Workout>> {
  WorkoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutControllerHash();

  @$internal
  @override
  WorkoutController create() => WorkoutController();
}

String _$workoutControllerHash() => r'dd3539fc392482fa5e4aab36d7dba64ca89b32b2';

abstract class _$WorkoutController extends $AsyncNotifier<List<Workout>> {
  FutureOr<List<Workout>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Workout>>, List<Workout>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Workout>>, List<Workout>>,
              AsyncValue<List<Workout>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
