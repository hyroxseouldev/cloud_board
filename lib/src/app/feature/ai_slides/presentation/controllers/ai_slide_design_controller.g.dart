// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slide_design_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlideDesignOwnerId)
final aiSlideDesignOwnerIdProvider = AiSlideDesignOwnerIdProvider._();

final class AiSlideDesignOwnerIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  AiSlideDesignOwnerIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlideDesignOwnerIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlideDesignOwnerIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return aiSlideDesignOwnerId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$aiSlideDesignOwnerIdHash() =>
    r'af7e14422aa0a327e54700042f71beee7f0571b5';

/// An absent onboarding record keeps the existing owner's library usable.
/// A real center ID is never replaced with the owner's UID.

@ProviderFor(aiSlideDesignStoreId)
final aiSlideDesignStoreIdProvider = AiSlideDesignStoreIdProvider._();

/// An absent onboarding record keeps the existing owner's library usable.
/// A real center ID is never replaced with the owner's UID.

final class AiSlideDesignStoreIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// An absent onboarding record keeps the existing owner's library usable.
  /// A real center ID is never replaced with the owner's UID.
  AiSlideDesignStoreIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlideDesignStoreIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlideDesignStoreIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return aiSlideDesignStoreId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$aiSlideDesignStoreIdHash() =>
    r'44b0176eaa7ad4a03ec3812c85d39b6579b1343d';

@ProviderFor(AiSlideDesignController)
final aiSlideDesignControllerProvider = AiSlideDesignControllerProvider._();

final class AiSlideDesignControllerProvider
    extends
        $NotifierProvider<AiSlideDesignController, AiSlideDesignStudioState> {
  AiSlideDesignControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlideDesignControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlideDesignControllerHash();

  @$internal
  @override
  AiSlideDesignController create() => AiSlideDesignController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlideDesignStudioState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlideDesignStudioState>(value),
    );
  }
}

String _$aiSlideDesignControllerHash() =>
    r'c2e84a468ef9103d6eb2f6bc68e3aa7d9e78d112';

abstract class _$AiSlideDesignController
    extends $Notifier<AiSlideDesignStudioState> {
  AiSlideDesignStudioState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AiSlideDesignStudioState, AiSlideDesignStudioState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiSlideDesignStudioState, AiSlideDesignStudioState>,
              AiSlideDesignStudioState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
