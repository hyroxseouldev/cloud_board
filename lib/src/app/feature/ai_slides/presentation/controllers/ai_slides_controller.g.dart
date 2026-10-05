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

String _$aiSlidesAccessHash() => r'cd1c401044ff400596d5f1b9cc69f5be8eba3869';

@ProviderFor(AiSlidesController)
final aiSlidesControllerProvider = AiSlidesControllerProvider._();

final class AiSlidesControllerProvider
    extends $NotifierProvider<AiSlidesController, AsyncValue<AiSlidesResult?>> {
  AiSlidesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesControllerHash();

  @$internal
  @override
  AiSlidesController create() => AiSlidesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AiSlidesResult?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AiSlidesResult?>>(value),
    );
  }
}

String _$aiSlidesControllerHash() =>
    r'c997c539a455d64ea153a5a5d44d61e4333c7844';

abstract class _$AiSlidesController
    extends $Notifier<AsyncValue<AiSlidesResult?>> {
  AsyncValue<AiSlidesResult?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<AiSlidesResult?>, AsyncValue<AiSlidesResult?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AiSlidesResult?>,
                AsyncValue<AiSlidesResult?>
              >,
              AsyncValue<AiSlidesResult?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
