// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlidesActions)
final aiSlidesActionsProvider = AiSlidesActionsProvider._();

final class AiSlidesActionsProvider
    extends
        $FunctionalProvider<AiSlidesActions, AiSlidesActions, AiSlidesActions>
    with $Provider<AiSlidesActions> {
  AiSlidesActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesActionsHash();

  @$internal
  @override
  $ProviderElement<AiSlidesActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiSlidesActions create(Ref ref) {
    return aiSlidesActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlidesActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlidesActions>(value),
    );
  }
}

String _$aiSlidesActionsHash() => r'ea557806847e3c1d6ba8195af01ff975e0b883f9';
