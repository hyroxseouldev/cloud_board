// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_local_data_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutLocalDataSource)
final workoutLocalDataSourceProvider = WorkoutLocalDataSourceProvider._();

final class WorkoutLocalDataSourceProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutLocalDataSource>,
          WorkoutLocalDataSource,
          FutureOr<WorkoutLocalDataSource>
        >
    with
        $FutureModifier<WorkoutLocalDataSource>,
        $FutureProvider<WorkoutLocalDataSource> {
  WorkoutLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutLocalDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutLocalDataSourceHash();

  @$internal
  @override
  $FutureProviderElement<WorkoutLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkoutLocalDataSource> create(Ref ref) {
    return workoutLocalDataSource(ref);
  }
}

String _$workoutLocalDataSourceHash() =>
    r'4d192a82ef48cb452d2caae14031a5db40771371';
