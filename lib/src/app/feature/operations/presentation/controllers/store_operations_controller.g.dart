// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_operations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(brandTemplate)
final brandTemplateProvider = BrandTemplateProvider._();

final class BrandTemplateProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrandTemplate>,
          BrandTemplate,
          Stream<BrandTemplate>
        >
    with $FutureModifier<BrandTemplate>, $StreamProvider<BrandTemplate> {
  BrandTemplateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brandTemplateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brandTemplateHash();

  @$internal
  @override
  $StreamProviderElement<BrandTemplate> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BrandTemplate> create(Ref ref) {
    return brandTemplate(ref);
  }
}

String _$brandTemplateHash() => r'25add325aa4fce962dbe5b45eae62cea056e9f74';

@ProviderFor(workoutSchedules)
final workoutSchedulesProvider = WorkoutSchedulesProvider._();

final class WorkoutSchedulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkoutSchedule>>,
          List<WorkoutSchedule>,
          Stream<List<WorkoutSchedule>>
        >
    with
        $FutureModifier<List<WorkoutSchedule>>,
        $StreamProvider<List<WorkoutSchedule>> {
  WorkoutSchedulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutSchedulesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutSchedulesHash();

  @$internal
  @override
  $StreamProviderElement<List<WorkoutSchedule>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<WorkoutSchedule>> create(Ref ref) {
    return workoutSchedules(ref);
  }
}

String _$workoutSchedulesHash() => r'641d120db572565a59e2b0702d7b002e62e87183';

@ProviderFor(operationEvents)
final operationEventsProvider = OperationEventsProvider._();

final class OperationEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<OperationEvent>>,
          List<OperationEvent>,
          Stream<List<OperationEvent>>
        >
    with
        $FutureModifier<List<OperationEvent>>,
        $StreamProvider<List<OperationEvent>> {
  OperationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationEventsHash();

  @$internal
  @override
  $StreamProviderElement<List<OperationEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<OperationEvent>> create(Ref ref) {
    return operationEvents(ref);
  }
}

String _$operationEventsHash() => r'5576f44cc7904b9f26cefc2a1d8cfdbdef5783d7';

@ProviderFor(operationsReport)
final operationsReportProvider = OperationsReportProvider._();

final class OperationsReportProvider
    extends
        $FunctionalProvider<
          OperationsReport,
          OperationsReport,
          OperationsReport
        >
    with $Provider<OperationsReport> {
  OperationsReportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationsReportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationsReportHash();

  @$internal
  @override
  $ProviderElement<OperationsReport> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OperationsReport create(Ref ref) {
    return operationsReport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OperationsReport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OperationsReport>(value),
    );
  }
}

String _$operationsReportHash() => r'a0f2b05c2b2621a26cea6fd7aba5261a1160cedc';

@ProviderFor(StoreOperationsActionController)
final storeOperationsActionControllerProvider =
    StoreOperationsActionControllerProvider._();

final class StoreOperationsActionControllerProvider
    extends
        $NotifierProvider<StoreOperationsActionController, AsyncValue<void>> {
  StoreOperationsActionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeOperationsActionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeOperationsActionControllerHash();

  @$internal
  @override
  StoreOperationsActionController create() => StoreOperationsActionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$storeOperationsActionControllerHash() =>
    r'b2f42142455d7536b8c248c414f930f756e37636';

abstract class _$StoreOperationsActionController
    extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
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
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ScheduleRunnerController)
final scheduleRunnerControllerProvider = ScheduleRunnerControllerProvider._();

final class ScheduleRunnerControllerProvider
    extends $NotifierProvider<ScheduleRunnerController, AsyncValue<void>> {
  ScheduleRunnerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduleRunnerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduleRunnerControllerHash();

  @$internal
  @override
  ScheduleRunnerController create() => ScheduleRunnerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$scheduleRunnerControllerHash() =>
    r'c2804b9a14df8c9ee65ddb0e2906f53080eea3f2';

abstract class _$ScheduleRunnerController extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
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
    return element.handleCreate(ref, build);
  }
}
