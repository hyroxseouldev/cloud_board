// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'existing_member_access_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(existingMemberAccessActions)
final existingMemberAccessActionsProvider =
    ExistingMemberAccessActionsProvider._();

final class ExistingMemberAccessActionsProvider
    extends
        $FunctionalProvider<
          ExistingMemberAccessActions,
          ExistingMemberAccessActions,
          ExistingMemberAccessActions
        >
    with $Provider<ExistingMemberAccessActions> {
  ExistingMemberAccessActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'existingMemberAccessActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$existingMemberAccessActionsHash();

  @$internal
  @override
  $ProviderElement<ExistingMemberAccessActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExistingMemberAccessActions create(Ref ref) {
    return existingMemberAccessActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExistingMemberAccessActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExistingMemberAccessActions>(value),
    );
  }
}

String _$existingMemberAccessActionsHash() =>
    r'7d4c3e4b3cf8f7bc9dc85625727051e8e1a2ff40';
