// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pairing_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(devicePairingRepository)
final devicePairingRepositoryProvider = DevicePairingRepositoryProvider._();

final class DevicePairingRepositoryProvider
    extends
        $FunctionalProvider<
          DevicePairingRepository,
          DevicePairingRepository,
          DevicePairingRepository
        >
    with $Provider<DevicePairingRepository> {
  DevicePairingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicePairingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicePairingRepositoryHash();

  @$internal
  @override
  $ProviderElement<DevicePairingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DevicePairingRepository create(Ref ref) {
    return devicePairingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevicePairingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevicePairingRepository>(value),
    );
  }
}

String _$devicePairingRepositoryHash() =>
    r'82e5f147261c7d44eb6dab18ce63afecf417c336';
