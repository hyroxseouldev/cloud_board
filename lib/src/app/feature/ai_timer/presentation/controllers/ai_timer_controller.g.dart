// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_timer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiTimerAccess)
final aiTimerAccessProvider = AiTimerAccessProvider._();

final class AiTimerAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<AiTimerAccess>,
          AiTimerAccess,
          FutureOr<AiTimerAccess>
        >
    with $FutureModifier<AiTimerAccess>, $FutureProvider<AiTimerAccess> {
  AiTimerAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiTimerAccessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiTimerAccessHash();

  @$internal
  @override
  $FutureProviderElement<AiTimerAccess> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AiTimerAccess> create(Ref ref) {
    return aiTimerAccess(ref);
  }
}

String _$aiTimerAccessHash() => r'34ece791786cd1a327676df7ed03ccf7b5112859';

@ProviderFor(AiTimerController)
final aiTimerControllerProvider = AiTimerControllerProvider._();

final class AiTimerControllerProvider
    extends
        $NotifierProvider<AiTimerController, AsyncValue<AiTimerSuggestion?>> {
  AiTimerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiTimerControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiTimerControllerHash();

  @$internal
  @override
  AiTimerController create() => AiTimerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AiTimerSuggestion?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AiTimerSuggestion?>>(
        value,
      ),
    );
  }
}

String _$aiTimerControllerHash() => r'21ca39ccca66a178b3ae82372193bcf130907365';

abstract class _$AiTimerController
    extends $Notifier<AsyncValue<AiTimerSuggestion?>> {
  AsyncValue<AiTimerSuggestion?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AiTimerSuggestion?>,
              AsyncValue<AiTimerSuggestion?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AiTimerSuggestion?>,
                AsyncValue<AiTimerSuggestion?>
              >,
              AsyncValue<AiTimerSuggestion?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
