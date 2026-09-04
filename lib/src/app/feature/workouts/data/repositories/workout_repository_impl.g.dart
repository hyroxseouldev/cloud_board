// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutRepository)
final workoutRepositoryProvider = WorkoutRepositoryProvider._();

final class WorkoutRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutRepository>,
          WorkoutRepository,
          FutureOr<WorkoutRepository>
        >
    with
        $FutureModifier<WorkoutRepository>,
        $FutureProvider<WorkoutRepository> {
  WorkoutRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<WorkoutRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkoutRepository> create(Ref ref) {
    return workoutRepository(ref);
  }
}

String _$workoutRepositoryHash() => r'0ff5200861e29c731f6ef0d54ffb30a2ab05bc37';
