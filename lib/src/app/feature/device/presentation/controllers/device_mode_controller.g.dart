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
    r'aceed83cbbd977395d10059903e02e6edbbabfc8';

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
