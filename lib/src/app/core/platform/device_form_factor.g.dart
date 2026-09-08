// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_form_factor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(androidTv)
final androidTvProvider = AndroidTvProvider._();

final class AndroidTvProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  AndroidTvProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'androidTvProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$androidTvHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return androidTv(ref);
  }
}

String _$androidTvHash() => r'cadda1b8f0d0858666f6be93764898940f9846b1';
