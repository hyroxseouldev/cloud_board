// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'beep_player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(beepPlayer)
final beepPlayerProvider = BeepPlayerProvider._();

final class BeepPlayerProvider
    extends $FunctionalProvider<BeepPlayer, BeepPlayer, BeepPlayer>
    with $Provider<BeepPlayer> {
  BeepPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'beepPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$beepPlayerHash();

  @$internal
  @override
  $ProviderElement<BeepPlayer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BeepPlayer create(Ref ref) {
    return beepPlayer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BeepPlayer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BeepPlayer>(value),
    );
  }
}

String _$beepPlayerHash() => r'248baa38eb64423eabced247aaec3371435737e0';
