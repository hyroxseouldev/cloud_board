// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supportActions)
final supportActionsProvider = SupportActionsProvider._();

final class SupportActionsProvider
    extends $FunctionalProvider<SupportActions, SupportActions, SupportActions>
    with $Provider<SupportActions> {
  SupportActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportActionsHash();

  @$internal
  @override
  $ProviderElement<SupportActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupportActions create(Ref ref) {
    return supportActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupportActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupportActions>(value),
    );
  }
}

String _$supportActionsHash() => r'61b39c7f738a9bf300822739b867e7f7721de488';
