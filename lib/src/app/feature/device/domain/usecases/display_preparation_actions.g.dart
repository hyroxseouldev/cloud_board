// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_preparation_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displayPreparationActions)
final displayPreparationActionsProvider = DisplayPreparationActionsProvider._();

final class DisplayPreparationActionsProvider
    extends
        $FunctionalProvider<
          DisplayPreparationActions,
          DisplayPreparationActions,
          DisplayPreparationActions
        >
    with $Provider<DisplayPreparationActions> {
  DisplayPreparationActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayPreparationActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayPreparationActionsHash();

  @$internal
  @override
  $ProviderElement<DisplayPreparationActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisplayPreparationActions create(Ref ref) {
    return displayPreparationActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayPreparationActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayPreparationActions>(value),
    );
  }
}

String _$displayPreparationActionsHash() =>
    r'4838aa1cdff90173c79cd7a25a288e3f21c0d9b0';
