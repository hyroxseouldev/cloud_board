// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(devicePairingActions)
final devicePairingActionsProvider = DevicePairingActionsProvider._();

final class DevicePairingActionsProvider
    extends
        $FunctionalProvider<
          DevicePairingActions,
          DevicePairingActions,
          DevicePairingActions
        >
    with $Provider<DevicePairingActions> {
  DevicePairingActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicePairingActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicePairingActionsHash();

  @$internal
  @override
  $ProviderElement<DevicePairingActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DevicePairingActions create(Ref ref) {
    return devicePairingActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevicePairingActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevicePairingActions>(value),
    );
  }
}

String _$devicePairingActionsHash() =>
    r'd43841558e95dfb135285adb10aa5874856769b1';
