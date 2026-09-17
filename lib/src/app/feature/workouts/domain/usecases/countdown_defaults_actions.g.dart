// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_defaults_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(countdownDefaultsActions)
final countdownDefaultsActionsProvider = CountdownDefaultsActionsProvider._();

final class CountdownDefaultsActionsProvider
    extends
        $FunctionalProvider<
          CountdownDefaultsActions,
          CountdownDefaultsActions,
          CountdownDefaultsActions
        >
    with $Provider<CountdownDefaultsActions> {
  CountdownDefaultsActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countdownDefaultsActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countdownDefaultsActionsHash();

  @$internal
  @override
  $ProviderElement<CountdownDefaultsActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CountdownDefaultsActions create(Ref ref) {
    return countdownDefaultsActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CountdownDefaultsActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CountdownDefaultsActions>(value),
    );
  }
}

String _$countdownDefaultsActionsHash() =>
    r'365f957bc66182c6aa3bccc982a01202e39cce1f';
