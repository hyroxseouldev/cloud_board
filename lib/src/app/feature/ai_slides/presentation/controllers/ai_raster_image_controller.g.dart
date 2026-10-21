// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_raster_image_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiRasterImageCache)
final aiRasterImageCacheProvider = AiRasterImageCacheProvider._();

final class AiRasterImageCacheProvider
    extends
        $FunctionalProvider<
          PrivateSlideImageCache,
          PrivateSlideImageCache,
          PrivateSlideImageCache
        >
    with $Provider<PrivateSlideImageCache> {
  AiRasterImageCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiRasterImageCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiRasterImageCacheHash();

  @$internal
  @override
  $ProviderElement<PrivateSlideImageCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrivateSlideImageCache create(Ref ref) {
    return aiRasterImageCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivateSlideImageCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivateSlideImageCache>(value),
    );
  }
}

String _$aiRasterImageCacheHash() =>
    r'5cb72ce8eb08612d5ff5209dd28a643a00cb426f';

@ProviderFor(aiRasterImage)
final aiRasterImageProvider = AiRasterImageFamily._();

final class AiRasterImageProvider
    extends
        $FunctionalProvider<
          AsyncValue<ui.Image?>,
          ui.Image?,
          FutureOr<ui.Image?>
        >
    with $FutureModifier<ui.Image?>, $FutureProvider<ui.Image?> {
  AiRasterImageProvider._({
    required AiRasterImageFamily super.from,
    required (AiRasterBrand, AiRasterJob?, String) super.argument,
  }) : super(
         retry: null,
         name: r'aiRasterImageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$aiRasterImageHash();

  @override
  String toString() {
    return r'aiRasterImageProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ui.Image?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ui.Image?> create(Ref ref) {
    final argument = this.argument as (AiRasterBrand, AiRasterJob?, String);
    return aiRasterImage(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is AiRasterImageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aiRasterImageHash() => r'4aad0a1d1dcf8994465c08bb504133da4a174347';

final class AiRasterImageFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ui.Image?>,
          (AiRasterBrand, AiRasterJob?, String)
        > {
  AiRasterImageFamily._()
    : super(
        retry: null,
        name: r'aiRasterImageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AiRasterImageProvider call(
    AiRasterBrand brand,
    AiRasterJob? job,
    String kind,
  ) => AiRasterImageProvider._(argument: (brand, job, kind), from: this);

  @override
  String toString() => r'aiRasterImageProvider';
}
