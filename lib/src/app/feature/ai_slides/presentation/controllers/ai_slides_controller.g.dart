// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlidesAccess)
final aiSlidesAccessProvider = AiSlidesAccessProvider._();

final class AiSlidesAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<AiSlidesAccess>,
          AiSlidesAccess,
          FutureOr<AiSlidesAccess>
        >
    with $FutureModifier<AiSlidesAccess>, $FutureProvider<AiSlidesAccess> {
  AiSlidesAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesAccessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesAccessHash();

  @$internal
  @override
  $FutureProviderElement<AiSlidesAccess> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AiSlidesAccess> create(Ref ref) {
    return aiSlidesAccess(ref);
  }
}

String _$aiSlidesAccessHash() => r'c098c37cfb43489ae5621500efb0f94fe5a85a48';

/// An anonymous display must never share its linked account's editing cache.

@ProviderFor(aiSlidesOwnerId)
final aiSlidesOwnerIdProvider = AiSlidesOwnerIdProvider._();

/// An anonymous display must never share its linked account's editing cache.

final class AiSlidesOwnerIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// An anonymous display must never share its linked account's editing cache.
  AiSlidesOwnerIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesOwnerIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesOwnerIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return aiSlidesOwnerId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$aiSlidesOwnerIdHash() => r'157df2d9212da6b9cf4e83120ad232e69efd6fc3';

@ProviderFor(AiSlidesController)
final aiSlidesControllerProvider = AiSlidesControllerProvider._();

final class AiSlidesControllerProvider
    extends $NotifierProvider<AiSlidesController, AiSlidesEditorState> {
  AiSlidesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesControllerHash();

  @$internal
  @override
  AiSlidesController create() => AiSlidesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlidesEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlidesEditorState>(value),
    );
  }
}

String _$aiSlidesControllerHash() =>
    r'fd193ecd8691c1fce1009b92ab1419b7d9c40d66';

abstract class _$AiSlidesController extends $Notifier<AiSlidesEditorState> {
  AiSlidesEditorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AiSlidesEditorState, AiSlidesEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiSlidesEditorState, AiSlidesEditorState>,
              AiSlidesEditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
