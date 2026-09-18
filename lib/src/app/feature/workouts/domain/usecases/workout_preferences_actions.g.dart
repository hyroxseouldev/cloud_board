// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_preferences_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutPreferencesActions)
final workoutPreferencesActionsProvider = WorkoutPreferencesActionsProvider._();

final class WorkoutPreferencesActionsProvider
    extends
        $FunctionalProvider<
          WorkoutPreferencesActions,
          WorkoutPreferencesActions,
          WorkoutPreferencesActions
        >
    with $Provider<WorkoutPreferencesActions> {
  WorkoutPreferencesActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutPreferencesActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutPreferencesActionsHash();

  @$internal
  @override
  $ProviderElement<WorkoutPreferencesActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutPreferencesActions create(Ref ref) {
    return workoutPreferencesActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutPreferencesActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutPreferencesActions>(value),
    );
  }
}

String _$workoutPreferencesActionsHash() =>
    r'40dd60457f464781530335be7e94dee351642ab5';
