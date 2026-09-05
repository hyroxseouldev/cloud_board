// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_mode_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(loadDeviceMode)
final loadDeviceModeProvider = LoadDeviceModeProvider._();

final class LoadDeviceModeProvider
    extends
        $FunctionalProvider<
          AsyncValue<LoadDeviceMode>,
          LoadDeviceMode,
          FutureOr<LoadDeviceMode>
        >
    with $FutureModifier<LoadDeviceMode>, $FutureProvider<LoadDeviceMode> {
  LoadDeviceModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loadDeviceModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loadDeviceModeHash();

  @$internal
  @override
  $FutureProviderElement<LoadDeviceMode> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LoadDeviceMode> create(Ref ref) {
    return loadDeviceMode(ref);
  }
}

String _$loadDeviceModeHash() => r'53f69628f1741636e6220dd3d1da7158561d6926';

@ProviderFor(saveDeviceMode)
final saveDeviceModeProvider = SaveDeviceModeProvider._();

final class SaveDeviceModeProvider
    extends
        $FunctionalProvider<
          AsyncValue<SaveDeviceMode>,
          SaveDeviceMode,
          FutureOr<SaveDeviceMode>
        >
    with $FutureModifier<SaveDeviceMode>, $FutureProvider<SaveDeviceMode> {
  SaveDeviceModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveDeviceModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveDeviceModeHash();

  @$internal
  @override
  $FutureProviderElement<SaveDeviceMode> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SaveDeviceMode> create(Ref ref) {
    return saveDeviceMode(ref);
  }
}

String _$saveDeviceModeHash() => r'470aaa854204a8b8f09f10b987c61a5b79dd363f';
