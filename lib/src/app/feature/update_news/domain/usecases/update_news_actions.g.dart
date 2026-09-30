// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_news_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateNewsActions)
final updateNewsActionsProvider = UpdateNewsActionsProvider._();

final class UpdateNewsActionsProvider
    extends
        $FunctionalProvider<
          UpdateNewsActions,
          UpdateNewsActions,
          UpdateNewsActions
        >
    with $Provider<UpdateNewsActions> {
  UpdateNewsActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNewsActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNewsActionsHash();

  @$internal
  @override
  $ProviderElement<UpdateNewsActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateNewsActions create(Ref ref) {
    return updateNewsActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateNewsActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateNewsActions>(value),
    );
  }
}

String _$updateNewsActionsHash() => r'abff7b450e7a6495aa7625fb840db0831148f4e4';
