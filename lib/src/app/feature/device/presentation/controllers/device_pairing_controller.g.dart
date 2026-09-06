// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DevicePairingController)
final devicePairingControllerProvider = DevicePairingControllerProvider._();

final class DevicePairingControllerProvider
    extends $AsyncNotifierProvider<DevicePairingController, DevicePairing> {
  DevicePairingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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
    r'f7976aa3dc7fe298b42b0afcc93df8ecd53724b2';

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

String _$displayDevicesHash() => r'6653373d2e6d934d6b0fc242fec45e27a396d5a5';

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
    r'33cac2da000fbfa2e3eb5ca4595de1eb5ba53bff';

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
