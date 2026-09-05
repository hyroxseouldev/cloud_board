// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_mode_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceModeRepository)
final deviceModeRepositoryProvider = DeviceModeRepositoryProvider._();

final class DeviceModeRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeviceModeRepository>,
          DeviceModeRepository,
          FutureOr<DeviceModeRepository>
        >
    with
        $FutureModifier<DeviceModeRepository>,
        $FutureProvider<DeviceModeRepository> {
  DeviceModeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceModeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceModeRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<DeviceModeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeviceModeRepository> create(Ref ref) {
    return deviceModeRepository(ref);
  }
}

String _$deviceModeRepositoryHash() =>
    r'7e3cc7bc2e73c64ab768f215113765a8be497cc9';

@ProviderFor(deviceId)
final deviceIdProvider = DeviceIdProvider._();

final class DeviceIdProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  DeviceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceIdHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return deviceId(ref);
  }
}

String _$deviceIdHash() => r'0a9c1e16021cbc102b7e076f3f1731c4956dcae5';
