// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_recovery_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DisplayRecoveryController)
final displayRecoveryControllerProvider = DisplayRecoveryControllerFamily._();

final class DisplayRecoveryControllerProvider
    extends
        $NotifierProvider<
          DisplayRecoveryController,
          AsyncValue<DisplayRecoveryRequest?>
        > {
  DisplayRecoveryControllerProvider._({
    required DisplayRecoveryControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'displayRecoveryControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$displayRecoveryControllerHash();

  @override
  String toString() {
    return r'displayRecoveryControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DisplayRecoveryController create() => DisplayRecoveryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<DisplayRecoveryRequest?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DisplayRecoveryRequest?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayRecoveryControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$displayRecoveryControllerHash() =>
    r'd9ff94aabd9928a7d4e390d2d0e39b5d95b79ff3';

final class DisplayRecoveryControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DisplayRecoveryController,
          AsyncValue<DisplayRecoveryRequest?>,
          AsyncValue<DisplayRecoveryRequest?>,
          AsyncValue<DisplayRecoveryRequest?>,
          String
        > {
  DisplayRecoveryControllerFamily._()
    : super(
        retry: null,
        name: r'displayRecoveryControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DisplayRecoveryControllerProvider call(String deviceId) =>
      DisplayRecoveryControllerProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'displayRecoveryControllerProvider';
}

abstract class _$DisplayRecoveryController
    extends $Notifier<AsyncValue<DisplayRecoveryRequest?>> {
  late final _$args = ref.$arg as String;
  String get deviceId => _$args;

  AsyncValue<DisplayRecoveryRequest?> build(String deviceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DisplayRecoveryRequest?>,
              AsyncValue<DisplayRecoveryRequest?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DisplayRecoveryRequest?>,
                AsyncValue<DisplayRecoveryRequest?>
              >,
              AsyncValue<DisplayRecoveryRequest?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(displayRecoveryRequest)
final displayRecoveryRequestProvider = DisplayRecoveryRequestFamily._();

final class DisplayRecoveryRequestProvider
    extends
        $FunctionalProvider<
          AsyncValue<DisplayRecoveryRequest?>,
          DisplayRecoveryRequest?,
          Stream<DisplayRecoveryRequest?>
        >
    with
        $FutureModifier<DisplayRecoveryRequest?>,
        $StreamProvider<DisplayRecoveryRequest?> {
  DisplayRecoveryRequestProvider._({
    required DisplayRecoveryRequestFamily super.from,
    required String super.argument,
  }) : super(
         retry: displayRecoveryRetry,
         name: r'displayRecoveryRequestProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$displayRecoveryRequestHash();

  @override
  String toString() {
    return r'displayRecoveryRequestProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<DisplayRecoveryRequest?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DisplayRecoveryRequest?> create(Ref ref) {
    final argument = this.argument as String;
    return displayRecoveryRequest(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayRecoveryRequestProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$displayRecoveryRequestHash() =>
    r'6594a32dd2560097092aa3682b853aae83ad9b68';

final class DisplayRecoveryRequestFamily extends $Family
    with $FunctionalFamilyOverride<Stream<DisplayRecoveryRequest?>, String> {
  DisplayRecoveryRequestFamily._()
    : super(
        retry: displayRecoveryRetry,
        name: r'displayRecoveryRequestProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DisplayRecoveryRequestProvider call(String deviceId) =>
      DisplayRecoveryRequestProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'displayRecoveryRequestProvider';
}
