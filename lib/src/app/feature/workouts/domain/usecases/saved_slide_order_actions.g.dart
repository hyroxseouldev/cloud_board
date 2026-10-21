// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_slide_order_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(savedSlideOrderActions)
final savedSlideOrderActionsProvider = SavedSlideOrderActionsProvider._();

final class SavedSlideOrderActionsProvider
    extends
        $FunctionalProvider<
          SavedSlideOrderActions,
          SavedSlideOrderActions,
          SavedSlideOrderActions
        >
    with $Provider<SavedSlideOrderActions> {
  SavedSlideOrderActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedSlideOrderActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedSlideOrderActionsHash();

  @$internal
  @override
  $ProviderElement<SavedSlideOrderActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedSlideOrderActions create(Ref ref) {
    return savedSlideOrderActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedSlideOrderActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedSlideOrderActions>(value),
    );
  }
}

String _$savedSlideOrderActionsHash() =>
    r'a4ec1cfcf8228b30cbe3744514d3b057e2f86f28';
