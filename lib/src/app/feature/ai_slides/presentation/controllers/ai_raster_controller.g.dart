// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_raster_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AiRasterController)
final aiRasterControllerProvider = AiRasterControllerProvider._();

final class AiRasterControllerProvider
    extends $NotifierProvider<AiRasterController, AiRasterState> {
  AiRasterControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiRasterControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiRasterControllerHash();

  @$internal
  @override
  AiRasterController create() => AiRasterController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiRasterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiRasterState>(value),
    );
  }
}

String _$aiRasterControllerHash() =>
    r'bfb61363e76e073a9aef5c647950b2d00290131e';

abstract class _$AiRasterController extends $Notifier<AiRasterState> {
  AiRasterState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AiRasterState, AiRasterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiRasterState, AiRasterState>,
              AiRasterState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
