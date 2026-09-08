// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeviceModeController)
final deviceModeControllerProvider = DeviceModeControllerProvider._();

final class DeviceModeControllerProvider
    extends $AsyncNotifierProvider<DeviceModeController, DeviceMode> {
  DeviceModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceModeControllerHash();

  @$internal
  @override
  DeviceModeController create() => DeviceModeController();
}

String _$deviceModeControllerHash() =>
    r'9852270919772f2b26aff59195ab41e914ab729e';

abstract class _$DeviceModeController extends $AsyncNotifier<DeviceMode> {
  FutureOr<DeviceMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DeviceMode>, DeviceMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DeviceMode>, DeviceMode>,
              AsyncValue<DeviceMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
