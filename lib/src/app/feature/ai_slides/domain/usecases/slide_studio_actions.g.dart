// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_studio_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(slideStudioActions)
final slideStudioActionsProvider = SlideStudioActionsProvider._();

final class SlideStudioActionsProvider
    extends
        $FunctionalProvider<
          SlideStudioActions,
          SlideStudioActions,
          SlideStudioActions
        >
    with $Provider<SlideStudioActions> {
  SlideStudioActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slideStudioActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slideStudioActionsHash();

  @$internal
  @override
  $ProviderElement<SlideStudioActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SlideStudioActions create(Ref ref) {
    return slideStudioActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlideStudioActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlideStudioActions>(value),
    );
  }
}

String _$slideStudioActionsHash() =>
    r'472ef78b052ebcc2f9afdac6452c0375f36f8c3d';
