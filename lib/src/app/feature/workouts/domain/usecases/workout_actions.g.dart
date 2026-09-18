// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(loadWorkouts)
final loadWorkoutsProvider = LoadWorkoutsProvider._();

final class LoadWorkoutsProvider
    extends
        $FunctionalProvider<
          AsyncValue<LoadWorkouts>,
          LoadWorkouts,
          FutureOr<LoadWorkouts>
        >
    with $FutureModifier<LoadWorkouts>, $FutureProvider<LoadWorkouts> {
  LoadWorkoutsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loadWorkoutsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loadWorkoutsHash();

  @$internal
  @override
  $FutureProviderElement<LoadWorkouts> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LoadWorkouts> create(Ref ref) {
    return loadWorkouts(ref);
  }
}

String _$loadWorkoutsHash() => r'e4371c7d84080dec9b27a806b85b764feeb3d552';

@ProviderFor(saveWorkout)
final saveWorkoutProvider = SaveWorkoutProvider._();

final class SaveWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<SaveWorkout>,
          SaveWorkout,
          FutureOr<SaveWorkout>
        >
    with $FutureModifier<SaveWorkout>, $FutureProvider<SaveWorkout> {
  SaveWorkoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveWorkoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveWorkoutHash();

  @$internal
  @override
  $FutureProviderElement<SaveWorkout> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SaveWorkout> create(Ref ref) {
    return saveWorkout(ref);
  }
}

String _$saveWorkoutHash() => r'8e492bc3047c2df995f036e90afcbd41b516c41c';

@ProviderFor(deleteWorkout)
final deleteWorkoutProvider = DeleteWorkoutProvider._();

final class DeleteWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeleteWorkout>,
          DeleteWorkout,
          FutureOr<DeleteWorkout>
        >
    with $FutureModifier<DeleteWorkout>, $FutureProvider<DeleteWorkout> {
  DeleteWorkoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteWorkoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteWorkoutHash();

  @$internal
  @override
  $FutureProviderElement<DeleteWorkout> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeleteWorkout> create(Ref ref) {
    return deleteWorkout(ref);
  }
}

String _$deleteWorkoutHash() => r'5f1dfb43de4526007b6d98a1f17cb8a8a6a15382';
