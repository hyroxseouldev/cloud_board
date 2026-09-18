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
    r'9c0d39b4357fe9a9d555b9a490226b90f11f7e14';

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
    r'd95edc8dd04ce6b7542c42710d3cb4238835f7c4';

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
