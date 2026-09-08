// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutMediaController)
final workoutMediaControllerProvider = WorkoutMediaControllerProvider._();

final class WorkoutMediaControllerProvider
    extends
        $FunctionalProvider<
          WorkoutMediaController,
          WorkoutMediaController,
          WorkoutMediaController
        >
    with $Provider<WorkoutMediaController> {
  WorkoutMediaControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutMediaControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutMediaControllerHash();

  @$internal
  @override
  $ProviderElement<WorkoutMediaController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutMediaController create(Ref ref) {
    return workoutMediaController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutMediaController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutMediaController>(value),
    );
  }
}

String _$workoutMediaControllerHash() =>
    r'ca0bc0032d2f7dc27bf315d7b18883c031f8d2e4';
