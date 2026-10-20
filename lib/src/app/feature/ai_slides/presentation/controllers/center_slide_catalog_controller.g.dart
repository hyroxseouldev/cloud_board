// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'center_slide_catalog_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// An unresolved account/center never borrows AsyncValue's previous data.

@ProviderFor(centerSlideCatalogScope)
final centerSlideCatalogScopeProvider = CenterSlideCatalogScopeProvider._();

/// An unresolved account/center never borrows AsyncValue's previous data.

final class CenterSlideCatalogScopeProvider
    extends
        $FunctionalProvider<
          CenterSlideCatalogScope?,
          CenterSlideCatalogScope?,
          CenterSlideCatalogScope?
        >
    with $Provider<CenterSlideCatalogScope?> {
  /// An unresolved account/center never borrows AsyncValue's previous data.
  CenterSlideCatalogScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'centerSlideCatalogScopeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$centerSlideCatalogScopeHash();

  @$internal
  @override
  $ProviderElement<CenterSlideCatalogScope?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CenterSlideCatalogScope? create(Ref ref) {
    return centerSlideCatalogScope(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CenterSlideCatalogScope? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CenterSlideCatalogScope?>(value),
    );
  }
}

String _$centerSlideCatalogScopeHash() =>
    r'b9aacb73c7ee9a3d28640f9641f097f71d14b789';

@ProviderFor(centerSlideTemplateActions)
final centerSlideTemplateActionsProvider =
    CenterSlideTemplateActionsProvider._();

final class CenterSlideTemplateActionsProvider
    extends
        $FunctionalProvider<
          CenterSlideTemplateActions,
          CenterSlideTemplateActions,
          CenterSlideTemplateActions
        >
    with $Provider<CenterSlideTemplateActions> {
  CenterSlideTemplateActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'centerSlideTemplateActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$centerSlideTemplateActionsHash();

  @$internal
  @override
  $ProviderElement<CenterSlideTemplateActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CenterSlideTemplateActions create(Ref ref) {
    return centerSlideTemplateActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CenterSlideTemplateActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CenterSlideTemplateActions>(value),
    );
  }
}

String _$centerSlideTemplateActionsHash() =>
    r'77d53d3687de43b4688520a4f5c076637e605bdd';

@ProviderFor(centerSlideCatalog)
final centerSlideCatalogProvider = CenterSlideCatalogProvider._();

final class CenterSlideCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<CenterSlideCatalog>,
          CenterSlideCatalog,
          Stream<CenterSlideCatalog>
        >
    with
        $FutureModifier<CenterSlideCatalog>,
        $StreamProvider<CenterSlideCatalog> {
  CenterSlideCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'centerSlideCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$centerSlideCatalogHash();

  @$internal
  @override
  $StreamProviderElement<CenterSlideCatalog> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CenterSlideCatalog> create(Ref ref) {
    return centerSlideCatalog(ref);
  }
}

String _$centerSlideCatalogHash() =>
    r'44978402b0b76714fcb050f29e8143703dce77e7';

/// One decode per recipe/scope, independent of every text edit.

@ProviderFor(centerSlideBackground)
final centerSlideBackgroundProvider = CenterSlideBackgroundFamily._();

/// One decode per recipe/scope, independent of every text edit.

final class CenterSlideBackgroundProvider
    extends
        $FunctionalProvider<
          AsyncValue<ui.Image?>,
          ui.Image?,
          FutureOr<ui.Image?>
        >
    with $FutureModifier<ui.Image?>, $FutureProvider<ui.Image?> {
  /// One decode per recipe/scope, independent of every text edit.
  CenterSlideBackgroundProvider._({
    required CenterSlideBackgroundFamily super.from,
    required CenterSlideRecipe super.argument,
  }) : super(
         retry: null,
         name: r'centerSlideBackgroundProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$centerSlideBackgroundHash();

  @override
  String toString() {
    return r'centerSlideBackgroundProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ui.Image?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ui.Image?> create(Ref ref) {
    final argument = this.argument as CenterSlideRecipe;
    return centerSlideBackground(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CenterSlideBackgroundProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$centerSlideBackgroundHash() =>
    r'ce9150c1e81b25c20bd94fa3e177940a1ec0d5af';

/// One decode per recipe/scope, independent of every text edit.

final class CenterSlideBackgroundFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ui.Image?>, CenterSlideRecipe> {
  CenterSlideBackgroundFamily._()
    : super(
        retry: null,
        name: r'centerSlideBackgroundProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One decode per recipe/scope, independent of every text edit.

  CenterSlideBackgroundProvider call(CenterSlideRecipe recipe) =>
      CenterSlideBackgroundProvider._(argument: recipe, from: this);

  @override
  String toString() => r'centerSlideBackgroundProvider';
}

@ProviderFor(centerSlidePreview)
final centerSlidePreviewProvider = CenterSlidePreviewFamily._();

final class CenterSlidePreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<CenterSlideLayout>,
          CenterSlideLayout,
          FutureOr<CenterSlideLayout>
        >
    with
        $FutureModifier<CenterSlideLayout>,
        $FutureProvider<CenterSlideLayout> {
  CenterSlidePreviewProvider._({
    required CenterSlidePreviewFamily super.from,
    required AiSlideDraft super.argument,
  }) : super(
         retry: null,
         name: r'centerSlidePreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$centerSlidePreviewHash();

  @override
  String toString() {
    return r'centerSlidePreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CenterSlideLayout> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CenterSlideLayout> create(Ref ref) {
    final argument = this.argument as AiSlideDraft;
    return centerSlidePreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CenterSlidePreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$centerSlidePreviewHash() =>
    r'5f8b35f26d3d5d8b307ecb8a3e87543961fcaf45';

final class CenterSlidePreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CenterSlideLayout>, AiSlideDraft> {
  CenterSlidePreviewFamily._()
    : super(
        retry: null,
        name: r'centerSlidePreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CenterSlidePreviewProvider call(AiSlideDraft draft) =>
      CenterSlidePreviewProvider._(argument: draft, from: this);

  @override
  String toString() => r'centerSlidePreviewProvider';
}

@ProviderFor(centerSlideImageCache)
final centerSlideImageCacheProvider = CenterSlideImageCacheProvider._();

final class CenterSlideImageCacheProvider
    extends
        $FunctionalProvider<
          PrivateSlideImageCache,
          PrivateSlideImageCache,
          PrivateSlideImageCache
        >
    with $Provider<PrivateSlideImageCache> {
  CenterSlideImageCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'centerSlideImageCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$centerSlideImageCacheHash();

  @$internal
  @override
  $ProviderElement<PrivateSlideImageCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrivateSlideImageCache create(Ref ref) {
    return centerSlideImageCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivateSlideImageCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivateSlideImageCache>(value),
    );
  }
}

String _$centerSlideImageCacheHash() =>
    r'26f848b416fb138bbab84f1e1172b4689dab3ccc';

@ProviderFor(centerSlideThumbnail)
final centerSlideThumbnailProvider = CenterSlideThumbnailFamily._();

final class CenterSlideThumbnailProvider
    extends
        $FunctionalProvider<
          AsyncValue<ui.Image?>,
          ui.Image?,
          FutureOr<ui.Image?>
        >
    with $FutureModifier<ui.Image?>, $FutureProvider<ui.Image?> {
  CenterSlideThumbnailProvider._({
    required CenterSlideThumbnailFamily super.from,
    required CenterSlideRecipe super.argument,
  }) : super(
         retry: null,
         name: r'centerSlideThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$centerSlideThumbnailHash();

  @override
  String toString() {
    return r'centerSlideThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ui.Image?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ui.Image?> create(Ref ref) {
    final argument = this.argument as CenterSlideRecipe;
    return centerSlideThumbnail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CenterSlideThumbnailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$centerSlideThumbnailHash() =>
    r'632e7a6aad4db7c11226e3900375dd7d17f6377b';

final class CenterSlideThumbnailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ui.Image?>, CenterSlideRecipe> {
  CenterSlideThumbnailFamily._()
    : super(
        retry: null,
        name: r'centerSlideThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CenterSlideThumbnailProvider call(CenterSlideRecipe recipe) =>
      CenterSlideThumbnailProvider._(argument: recipe, from: this);

  @override
  String toString() => r'centerSlideThumbnailProvider';
}
