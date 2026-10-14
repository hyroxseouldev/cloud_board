// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displayConnectionState)
final displayConnectionStateProvider = DisplayConnectionStateProvider._();

final class DisplayConnectionStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<DisplayConnectionState>,
          DisplayConnectionState,
          Stream<DisplayConnectionState>
        >
    with
        $FutureModifier<DisplayConnectionState>,
        $StreamProvider<DisplayConnectionState> {
  DisplayConnectionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noAutomaticPairingRetry,
        name: r'displayConnectionStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayConnectionStateHash();

  @$internal
  @override
  $StreamProviderElement<DisplayConnectionState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DisplayConnectionState> create(Ref ref) {
    return displayConnectionState(ref);
  }
}

String _$displayConnectionStateHash() =>
    r'45d3f24a89183a87c6c491558d37b8005ef829ad';

@ProviderFor(DevicePairingController)
final devicePairingControllerProvider = DevicePairingControllerProvider._();

final class DevicePairingControllerProvider
    extends $AsyncNotifierProvider<DevicePairingController, DevicePairing> {
  DevicePairingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noAutomaticPairingRetry,
        name: r'devicePairingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicePairingControllerHash();

  @$internal
  @override
  DevicePairingController create() => DevicePairingController();
}

String _$devicePairingControllerHash() =>
    r'a3352355b25c224835491ffd18f966228476fed9';

abstract class _$DevicePairingController extends $AsyncNotifier<DevicePairing> {
  FutureOr<DevicePairing> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DevicePairing>, DevicePairing>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DevicePairing>, DevicePairing>,
              AsyncValue<DevicePairing>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(displayDevices)
final displayDevicesProvider = DisplayDevicesProvider._();

final class DisplayDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DisplayDevice>>,
          List<DisplayDevice>,
          Stream<List<DisplayDevice>>
        >
    with
        $FutureModifier<List<DisplayDevice>>,
        $StreamProvider<List<DisplayDevice>> {
  DisplayDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayDevicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<DisplayDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DisplayDevice>> create(Ref ref) {
    return displayDevices(ref);
  }
}

String _$displayDevicesHash() => r'659028b0606db21e469cfb001c9d319ce8842ac4';

@ProviderFor(DeviceClaimController)
final deviceClaimControllerProvider = DeviceClaimControllerProvider._();

final class DeviceClaimControllerProvider
    extends $NotifierProvider<DeviceClaimController, AsyncValue<void>> {
  DeviceClaimControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceClaimControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceClaimControllerHash();

  @$internal
  @override
  DeviceClaimController create() => DeviceClaimController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$deviceClaimControllerHash() =>
    r'b0c281f30c72b368c75bb6b644f8e04f7fd223f2';

abstract class _$DeviceClaimController extends $Notifier<AsyncValue<void>> {
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

/// Re-evaluates stale heartbeats even when the database emits no new values.

@ProviderFor(displayHealthNow)
final displayHealthNowProvider = DisplayHealthNowProvider._();

/// Re-evaluates stale heartbeats even when the database emits no new values.

final class DisplayHealthNowProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Re-evaluates stale heartbeats even when the database emits no new values.
  DisplayHealthNowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayHealthNowProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayHealthNowHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return displayHealthNow(ref);
  }
}

String _$displayHealthNowHash() => r'fd5e0ac44687f5b48631be6e63b59ac61fc75301';
