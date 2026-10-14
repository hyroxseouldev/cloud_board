// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_recovery_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displayRecoveryActions)
final displayRecoveryActionsProvider = DisplayRecoveryActionsProvider._();

final class DisplayRecoveryActionsProvider
    extends
        $FunctionalProvider<
          DisplayRecoveryActions,
          DisplayRecoveryActions,
          DisplayRecoveryActions
        >
    with $Provider<DisplayRecoveryActions> {
  DisplayRecoveryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayRecoveryActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayRecoveryActionsHash();

  @$internal
  @override
  $ProviderElement<DisplayRecoveryActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisplayRecoveryActions create(Ref ref) {
    return displayRecoveryActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayRecoveryActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayRecoveryActions>(value),
    );
  }
}

String _$displayRecoveryActionsHash() =>
    r'b4ce65fcda9bf6a7d0d0714141a9cd0d2c41546a';
