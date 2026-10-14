// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_operations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audienceBrandingForOwner)
final audienceBrandingForOwnerProvider = AudienceBrandingForOwnerFamily._();

final class AudienceBrandingForOwnerProvider
    extends
        $FunctionalProvider<
          AsyncValue<AudienceBranding?>,
          AudienceBranding?,
          Stream<AudienceBranding?>
        >
    with
        $FutureModifier<AudienceBranding?>,
        $StreamProvider<AudienceBranding?> {
  AudienceBrandingForOwnerProvider._({
    required AudienceBrandingForOwnerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'audienceBrandingForOwnerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audienceBrandingForOwnerHash();

  @override
  String toString() {
    return r'audienceBrandingForOwnerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AudienceBranding?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AudienceBranding?> create(Ref ref) {
    final argument = this.argument as String;
    return audienceBrandingForOwner(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudienceBrandingForOwnerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audienceBrandingForOwnerHash() =>
    r'04a0335fa134432ea2fe69647e13a99bf4ebb8e0';

final class AudienceBrandingForOwnerFamily extends $Family
    with $FunctionalFamilyOverride<Stream<AudienceBranding?>, String> {
  AudienceBrandingForOwnerFamily._()
    : super(
        retry: null,
        name: r'audienceBrandingForOwnerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AudienceBrandingForOwnerProvider call(String ownerId) =>
      AudienceBrandingForOwnerProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'audienceBrandingForOwnerProvider';
}

/// Synchronous owner filtering prevents retained AsyncData from a previous
/// account appearing for even one frame during sign-out or TV re-pairing.

@ProviderFor(audienceBranding)
final audienceBrandingProvider = AudienceBrandingProvider._();

/// Synchronous owner filtering prevents retained AsyncData from a previous
/// account appearing for even one frame during sign-out or TV re-pairing.

final class AudienceBrandingProvider
    extends
        $FunctionalProvider<
          AudienceBranding?,
          AudienceBranding?,
          AudienceBranding?
        >
    with $Provider<AudienceBranding?> {
  /// Synchronous owner filtering prevents retained AsyncData from a previous
  /// account appearing for even one frame during sign-out or TV re-pairing.
  AudienceBrandingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audienceBrandingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audienceBrandingHash();

  @$internal
  @override
  $ProviderElement<AudienceBranding?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudienceBranding? create(Ref ref) {
    return audienceBranding(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudienceBranding? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudienceBranding?>(value),
    );
  }
}

String _$audienceBrandingHash() => r'9107f4aa74e8dbba2ebee05b3f768e246e2a9011';

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

@ProviderFor(effectiveBrandTemplate)
final effectiveBrandTemplateProvider = EffectiveBrandTemplateProvider._();

final class EffectiveBrandTemplateProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrandTemplate>,
          BrandTemplate,
          Stream<BrandTemplate>
        >
    with $FutureModifier<BrandTemplate>, $StreamProvider<BrandTemplate> {
  EffectiveBrandTemplateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'effectiveBrandTemplateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$effectiveBrandTemplateHash();

  @$internal
  @override
  $StreamProviderElement<BrandTemplate> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BrandTemplate> create(Ref ref) {
    return effectiveBrandTemplate(ref);
  }
}

String _$effectiveBrandTemplateHash() =>
    r'5fb85c4c7d985366551be124fe1d4ed9b1c98b6d';

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
    r'882f7a1d4a6eaf3bb85970745698d68da112e334';

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
