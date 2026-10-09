// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android_class_notifications.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-scoped projection only. Android's receiver owns notification commands,
/// including when there is no Flutter engine or player widget.

@ProviderFor(androidClassNotifications)
final androidClassNotificationsProvider = AndroidClassNotificationsProvider._();

/// App-scoped projection only. Android's receiver owns notification commands,
/// including when there is no Flutter engine or player widget.

final class AndroidClassNotificationsProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// App-scoped projection only. Android's receiver owns notification commands,
  /// including when there is no Flutter engine or player widget.
  AndroidClassNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'androidClassNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$androidClassNotificationsHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return androidClassNotifications(ref);
  }
}

String _$androidClassNotificationsHash() =>
    r'47d54c881b64432d86147e744065182027559c2c';
