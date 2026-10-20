// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_studio_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SlideStudioController)
final slideStudioControllerProvider = SlideStudioControllerProvider._();

final class SlideStudioControllerProvider
    extends $NotifierProvider<SlideStudioController, SlideStudioState> {
  SlideStudioControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slideStudioControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slideStudioControllerHash();

  @$internal
  @override
  SlideStudioController create() => SlideStudioController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlideStudioState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlideStudioState>(value),
    );
  }
}

String _$slideStudioControllerHash() =>
    r'6351aff2c61694b4b584770ae2969851f6445d0c';

abstract class _$SlideStudioController extends $Notifier<SlideStudioState> {
  SlideStudioState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SlideStudioState, SlideStudioState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SlideStudioState, SlideStudioState>,
              SlideStudioState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
