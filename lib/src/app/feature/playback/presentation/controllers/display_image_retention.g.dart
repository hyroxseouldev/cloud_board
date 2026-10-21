// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_image_retention.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Survives a display widget remount, but never an account/binding scope.

@ProviderFor(displayImageRetention)
final displayImageRetentionProvider = DisplayImageRetentionProvider._();

/// Survives a display widget remount, but never an account/binding scope.

final class DisplayImageRetentionProvider
    extends
        $FunctionalProvider<
          WorkoutImageRetention,
          WorkoutImageRetention,
          WorkoutImageRetention
        >
    with $Provider<WorkoutImageRetention> {
  /// Survives a display widget remount, but never an account/binding scope.
  DisplayImageRetentionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayImageRetentionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayImageRetentionHash();

  @$internal
  @override
  $ProviderElement<WorkoutImageRetention> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkoutImageRetention create(Ref ref) {
    return displayImageRetention(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkoutImageRetention value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkoutImageRetention>(value),
    );
  }
}

String _$displayImageRetentionHash() =>
    r'7d2951b2ef612e2d1fab997de4dbe64bcde44b57';
