// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_preferences_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutPreferencesRepository)
final workoutPreferencesRepositoryProvider =
    WorkoutPreferencesRepositoryProvider._();

final class WorkoutPreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          WorkoutPreferencesRepository,
          WorkoutPreferencesRepository,
          WorkoutPreferencesRepository
        >
    with $Provider<WorkoutPreferencesRepository> {
  WorkoutPreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutPreferencesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutPreferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkoutPreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutPreferencesRepository create(Ref ref) {
    return workoutPreferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutPreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutPreferencesRepository>(value),
    );
  }
}

String _$workoutPreferencesRepositoryHash() =>
    r'fe96cf814cb465a89893ef3f12aa749f49043d40';
