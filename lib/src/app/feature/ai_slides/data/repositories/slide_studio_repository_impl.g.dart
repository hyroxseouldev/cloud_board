// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_studio_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(slideStudioRepository)
final slideStudioRepositoryProvider = SlideStudioRepositoryProvider._();

final class SlideStudioRepositoryProvider
    extends
        $FunctionalProvider<
          SlideStudioRepository?,
          SlideStudioRepository?,
          SlideStudioRepository?
        >
    with $Provider<SlideStudioRepository?> {
  SlideStudioRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slideStudioRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slideStudioRepositoryHash();

  @$internal
  @override
  $ProviderElement<SlideStudioRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SlideStudioRepository? create(Ref ref) {
    return slideStudioRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlideStudioRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlideStudioRepository?>(value),
    );
  }
}

String _$slideStudioRepositoryHash() =>
    r'99d32f22ebe528d6c2d4c8de78849f4ceb1fada1';
