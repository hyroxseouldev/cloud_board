// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_display_auth.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A browser display has its own device identity. The owner's Google session
/// remains available to the controller and other tabs on the same origin.

@ProviderFor(webDisplayAuth)
final webDisplayAuthProvider = WebDisplayAuthFamily._();

/// A browser display has its own device identity. The owner's Google session
/// remains available to the controller and other tabs on the same origin.

final class WebDisplayAuthProvider
    extends
        $FunctionalProvider<
          AsyncValue<FirebaseAuth>,
          FirebaseAuth,
          FutureOr<FirebaseAuth>
        >
    with $FutureModifier<FirebaseAuth>, $FutureProvider<FirebaseAuth> {
  /// A browser display has its own device identity. The owner's Google session
  /// remains available to the controller and other tabs on the same origin.
  WebDisplayAuthProvider._({
    required WebDisplayAuthFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'webDisplayAuthProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$webDisplayAuthHash();

  @override
  String toString() {
    return r'webDisplayAuthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FirebaseAuth> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FirebaseAuth> create(Ref ref) {
    final argument = this.argument as String;
    return webDisplayAuth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WebDisplayAuthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$webDisplayAuthHash() => r'228b6b98b5ed70d4b12a9d63d495eb15a55a8ea4';

/// A browser display has its own device identity. The owner's Google session
/// remains available to the controller and other tabs on the same origin.

final class WebDisplayAuthFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FirebaseAuth>, String> {
  WebDisplayAuthFamily._()
    : super(
        retry: null,
        name: r'webDisplayAuthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// A browser display has its own device identity. The owner's Google session
  /// remains available to the controller and other tabs on the same origin.

  WebDisplayAuthProvider call(String ownerId) =>
      WebDisplayAuthProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'webDisplayAuthProvider';
}
