// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackActions)
final playbackActionsProvider = PlaybackActionsProvider._();

final class PlaybackActionsProvider
    extends
        $FunctionalProvider<PlaybackActions, PlaybackActions, PlaybackActions>
    with $Provider<PlaybackActions> {
  PlaybackActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackActionsHash();

  @$internal
  @override
  $ProviderElement<PlaybackActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlaybackActions create(Ref ref) {
    return playbackActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackActions>(value),
    );
  }
}

String _$playbackActionsHash() => r'f10853deb5f22322dfee055f93ef57ec81ce4563';
