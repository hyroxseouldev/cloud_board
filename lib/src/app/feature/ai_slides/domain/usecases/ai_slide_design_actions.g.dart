// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slide_design_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlideDesignActions)
final aiSlideDesignActionsProvider = AiSlideDesignActionsProvider._();

final class AiSlideDesignActionsProvider
    extends
        $FunctionalProvider<
          AiSlideDesignActions,
          AiSlideDesignActions,
          AiSlideDesignActions
        >
    with $Provider<AiSlideDesignActions> {
  AiSlideDesignActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlideDesignActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlideDesignActionsHash();

  @$internal
  @override
  $ProviderElement<AiSlideDesignActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiSlideDesignActions create(Ref ref) {
    return aiSlideDesignActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlideDesignActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlideDesignActions>(value),
    );
  }
}

String _$aiSlideDesignActionsHash() =>
    r'a3fff44cf562bb229346cbbdd09303a2e3164f88';
