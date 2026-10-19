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
    r'ef364bd611042859359322813cccbb3813aed281';

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

@ProviderFor(centerSlidePreview)
final centerSlidePreviewProvider = CenterSlidePreviewFamily._();

final class CenterSlidePreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List>,
          Uint8List,
          FutureOr<Uint8List>
        >
    with $FutureModifier<Uint8List>, $FutureProvider<Uint8List> {
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
  $FutureProviderElement<Uint8List> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List> create(Ref ref) {
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
    r'5735f784fc428a35d53f7be90d786d103ef4f7e5';

final class CenterSlidePreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List>, AiSlideDraft> {
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
