// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_editor_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(slideEditorActions)
final slideEditorActionsProvider = SlideEditorActionsProvider._();

final class SlideEditorActionsProvider
    extends
        $FunctionalProvider<
          SlideEditorActions,
          SlideEditorActions,
          SlideEditorActions
        >
    with $Provider<SlideEditorActions> {
  SlideEditorActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slideEditorActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slideEditorActionsHash();

  @$internal
  @override
  $ProviderElement<SlideEditorActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SlideEditorActions create(Ref ref) {
    return slideEditorActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlideEditorActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlideEditorActions>(value),
    );
  }
}

String _$slideEditorActionsHash() =>
    r'1a3307c6366d1bc592f7dd50413fb63ec9929f5e';
