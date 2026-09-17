// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutDetail)
final workoutDetailProvider = WorkoutDetailFamily._();

final class WorkoutDetailProvider
    extends $AsyncNotifierProvider<WorkoutDetail, Workout?> {
  WorkoutDetailProvider._({
    required WorkoutDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutDetailHash();

  @override
  String toString() {
    return r'workoutDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkoutDetail create() => WorkoutDetail();

  @override
  bool operator ==(Object other) {
    return other is WorkoutDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutDetailHash() => r'c34dc81e58327b7c0b2d032b9045af26ab29f578';

final class WorkoutDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkoutDetail,
          AsyncValue<Workout?>,
          Workout?,
          FutureOr<Workout?>,
          String
        > {
  WorkoutDetailFamily._()
    : super(
        retry: null,
        name: r'workoutDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WorkoutDetailProvider call(String id) =>
      WorkoutDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'workoutDetailProvider';
}

abstract class _$WorkoutDetail extends $AsyncNotifier<Workout?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<Workout?> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Workout?>, Workout?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Workout?>, Workout?>,
              AsyncValue<Workout?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(WorkoutController)
final workoutControllerProvider = WorkoutControllerProvider._();

final class WorkoutControllerProvider
    extends $StreamNotifierProvider<WorkoutController, List<WorkoutSummary>> {
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

String _$workoutControllerHash() => r'33026f7823ba4f14eedd434efc065031209e2b85';

abstract class _$WorkoutController
    extends $StreamNotifier<List<WorkoutSummary>> {
  Stream<List<WorkoutSummary>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<WorkoutSummary>>, List<WorkoutSummary>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<WorkoutSummary>>,
                List<WorkoutSummary>
              >,
              AsyncValue<List<WorkoutSummary>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(WorkoutActionController)
final workoutActionControllerProvider = WorkoutActionControllerProvider._();

final class WorkoutActionControllerProvider
    extends $NotifierProvider<WorkoutActionController, AsyncValue<String?>> {
  WorkoutActionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutActionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutActionControllerHash();

  @$internal
  @override
  WorkoutActionController create() => WorkoutActionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String?>>(value),
    );
  }
}

String _$workoutActionControllerHash() =>
    r'21e56252b0379f87f71c590fa9b2704b5a478783';

abstract class _$WorkoutActionController
    extends $Notifier<AsyncValue<String?>> {
  AsyncValue<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, AsyncValue<String?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, AsyncValue<String?>>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
