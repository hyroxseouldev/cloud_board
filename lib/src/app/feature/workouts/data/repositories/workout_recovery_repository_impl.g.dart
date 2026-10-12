// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_recovery_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutRecoveryRepository)
final workoutRecoveryRepositoryProvider = WorkoutRecoveryRepositoryProvider._();

final class WorkoutRecoveryRepositoryProvider
    extends
        $FunctionalProvider<
          WorkoutRecoveryRepository,
          WorkoutRecoveryRepository,
          WorkoutRecoveryRepository
        >
    with $Provider<WorkoutRecoveryRepository> {
  WorkoutRecoveryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutRecoveryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutRecoveryRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkoutRecoveryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutRecoveryRepository create(Ref ref) {
    return workoutRecoveryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutRecoveryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutRecoveryRepository>(value),
    );
  }
}

String _$workoutRecoveryRepositoryHash() =>
    r'96cc13a476e130b1cfa0e0bd7828c67e17d53289';
