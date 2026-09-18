// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_preferences_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accountWorkoutPreferences)
final accountWorkoutPreferencesProvider = AccountWorkoutPreferencesFamily._();

final class AccountWorkoutPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutPreferences>,
          WorkoutPreferences,
          FutureOr<WorkoutPreferences>
        >
    with
        $FutureModifier<WorkoutPreferences>,
        $FutureProvider<WorkoutPreferences> {
  AccountWorkoutPreferencesProvider._({
    required AccountWorkoutPreferencesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountWorkoutPreferencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountWorkoutPreferencesHash();

  @override
  String toString() {
    return r'accountWorkoutPreferencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WorkoutPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkoutPreferences> create(Ref ref) {
    final argument = this.argument as String;
    return accountWorkoutPreferences(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountWorkoutPreferencesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountWorkoutPreferencesHash() =>
    r'eeb9e84d123a519d66a583b23a7d5b4c4380b90d';

final class AccountWorkoutPreferencesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<WorkoutPreferences>, String> {
  AccountWorkoutPreferencesFamily._()
    : super(
        retry: null,
        name: r'accountWorkoutPreferencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountWorkoutPreferencesProvider call(String ownerId) =>
      AccountWorkoutPreferencesProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'accountWorkoutPreferencesProvider';
}

@ProviderFor(WorkoutPreferencesController)
final workoutPreferencesControllerProvider =
    WorkoutPreferencesControllerFamily._();

final class WorkoutPreferencesControllerProvider
    extends $NotifierProvider<WorkoutPreferencesController, AsyncValue<void>> {
  WorkoutPreferencesControllerProvider._({
    required WorkoutPreferencesControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutPreferencesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutPreferencesControllerHash();

  @override
  String toString() {
    return r'workoutPreferencesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkoutPreferencesController create() => WorkoutPreferencesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutPreferencesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutPreferencesControllerHash() =>
    r'152938af4fe1c09956dbcc61d192ed74f44b6c7f';

final class WorkoutPreferencesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkoutPreferencesController,
          AsyncValue<void>,
          AsyncValue<void>,
          AsyncValue<void>,
          String
        > {
  WorkoutPreferencesControllerFamily._()
    : super(
        retry: null,
        name: r'workoutPreferencesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkoutPreferencesControllerProvider call(String ownerId) =>
      WorkoutPreferencesControllerProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'workoutPreferencesControllerProvider';
}

abstract class _$WorkoutPreferencesController
    extends $Notifier<AsyncValue<void>> {
  late final _$args = ref.$arg as String;
  String get ownerId => _$args;

  AsyncValue<void> build(String ownerId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Derived rendering only. Raw detail providers remain independent of settings.

@ProviderFor(workoutPreview)
final workoutPreviewProvider = WorkoutPreviewFamily._();

/// Derived rendering only. Raw detail providers remain independent of settings.

final class WorkoutPreviewProvider
    extends $FunctionalProvider<AsyncValue<Workout>, Workout, FutureOr<Workout>>
    with $FutureModifier<Workout>, $FutureProvider<Workout> {
  /// Derived rendering only. Raw detail providers remain independent of settings.
  WorkoutPreviewProvider._({
    required WorkoutPreviewFamily super.from,
    required Workout super.argument,
  }) : super(
         retry: null,
         name: r'workoutPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutPreviewHash();

  @override
  String toString() {
    return r'workoutPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Workout> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Workout> create(Ref ref) {
    final argument = this.argument as Workout;
    return workoutPreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutPreviewHash() => r'0ae2e1c267f6383b68daa55f41454cae8bf1e5e7';

/// Derived rendering only. Raw detail providers remain independent of settings.

final class WorkoutPreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Workout>, Workout> {
  WorkoutPreviewFamily._()
    : super(
        retry: null,
        name: r'workoutPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Derived rendering only. Raw detail providers remain independent of settings.

  WorkoutPreviewProvider call(Workout workout) =>
      WorkoutPreviewProvider._(argument: workout, from: this);

  @override
  String toString() => r'workoutPreviewProvider';
}

@ProviderFor(localPlaybackWorkout)
final localPlaybackWorkoutProvider = LocalPlaybackWorkoutFamily._();

final class LocalPlaybackWorkoutProvider
    extends
        $FunctionalProvider<AsyncValue<Workout?>, Workout?, FutureOr<Workout?>>
    with $FutureModifier<Workout?>, $FutureProvider<Workout?> {
  LocalPlaybackWorkoutProvider._({
    required LocalPlaybackWorkoutFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'localPlaybackWorkoutProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$localPlaybackWorkoutHash();

  @override
  String toString() {
    return r'localPlaybackWorkoutProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Workout?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Workout?> create(Ref ref) {
    final argument = this.argument as String;
    return localPlaybackWorkout(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalPlaybackWorkoutProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$localPlaybackWorkoutHash() =>
    r'bd2e1db70fc8d984ccf0f90e9bf6d3885f0c1831';

final class LocalPlaybackWorkoutFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Workout?>, String> {
  LocalPlaybackWorkoutFamily._()
    : super(
        retry: null,
        name: r'localPlaybackWorkoutProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LocalPlaybackWorkoutProvider call(String id) =>
      LocalPlaybackWorkoutProvider._(argument: id, from: this);

  @override
  String toString() => r'localPlaybackWorkoutProvider';
}
