// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_playback_lifecycle.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TvPlaybackVisible)
final tvPlaybackVisibleProvider = TvPlaybackVisibleProvider._();

final class TvPlaybackVisibleProvider
    extends $NotifierProvider<TvPlaybackVisible, bool> {
  TvPlaybackVisibleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tvPlaybackVisibleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tvPlaybackVisibleHash();

  @$internal
  @override
  TvPlaybackVisible create() => TvPlaybackVisible();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$tvPlaybackVisibleHash() => r'bf324340c748d4aa37ba93e524a1150f2cba8396';

abstract class _$TvPlaybackVisible extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
