// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_editor_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlidesEditorActions)
final aiSlidesEditorActionsProvider = AiSlidesEditorActionsProvider._();

final class AiSlidesEditorActionsProvider
    extends
        $FunctionalProvider<
          AiSlidesEditorActions,
          AiSlidesEditorActions,
          AiSlidesEditorActions
        >
    with $Provider<AiSlidesEditorActions> {
  AiSlidesEditorActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesEditorActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesEditorActionsHash();

  @$internal
  @override
  $ProviderElement<AiSlidesEditorActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiSlidesEditorActions create(Ref ref) {
    return aiSlidesEditorActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlidesEditorActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlidesEditorActions>(value),
    );
  }
}

String _$aiSlidesEditorActionsHash() =>
    r'65078a3f18fcc5f47288587b14205c91dd138744';
