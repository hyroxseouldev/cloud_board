// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ios_class_controls.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Non-secret session binding for App Intents. Native FirebaseAuth supplies the
/// current credential at invocation; no ID/refresh token crosses this channel.

@ProviderFor(iosClassControls)
final iosClassControlsProvider = IosClassControlsProvider._();

/// Non-secret session binding for App Intents. Native FirebaseAuth supplies the
/// current credential at invocation; no ID/refresh token crosses this channel.

final class IosClassControlsProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Non-secret session binding for App Intents. Native FirebaseAuth supplies the
  /// current credential at invocation; no ID/refresh token crosses this channel.
  IosClassControlsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'iosClassControlsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$iosClassControlsHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return iosClassControls(ref);
  }
}

String _$iosClassControlsHash() => r'0770c439d9b743f3f21e74e4f702bb23eafad991';
