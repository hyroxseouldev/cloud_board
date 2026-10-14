// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_preparation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DisplayPreparationController)
final displayPreparationControllerProvider =
    DisplayPreparationControllerProvider._();

final class DisplayPreparationControllerProvider
    extends
        $NotifierProvider<
          DisplayPreparationController,
          DisplayPreparationState
        > {
  DisplayPreparationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayPreparationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayPreparationControllerHash();

  @$internal
  @override
  DisplayPreparationController create() => DisplayPreparationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayPreparationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayPreparationState>(value),
    );
  }
}

String _$displayPreparationControllerHash() =>
    r'0e38647cd496dfdc9155dfd86377637b8cafbe77';

abstract class _$DisplayPreparationController
    extends $Notifier<DisplayPreparationState> {
  DisplayPreparationState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<DisplayPreparationState, DisplayPreparationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DisplayPreparationState, DisplayPreparationState>,
              DisplayPreparationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(displayPreparationRequest)
final displayPreparationRequestProvider = DisplayPreparationRequestFamily._();

final class DisplayPreparationRequestProvider
    extends
        $FunctionalProvider<
          AsyncValue<DisplayPreparation?>,
          DisplayPreparation?,
          Stream<DisplayPreparation?>
        >
    with
        $FutureModifier<DisplayPreparation?>,
        $StreamProvider<DisplayPreparation?> {
  DisplayPreparationRequestProvider._({
    required DisplayPreparationRequestFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noAutomaticPreparationRetry,
         name: r'displayPreparationRequestProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$displayPreparationRequestHash();

  @override
  String toString() {
    return r'displayPreparationRequestProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<DisplayPreparation?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DisplayPreparation?> create(Ref ref) {
    final argument = this.argument as String;
    return displayPreparationRequest(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayPreparationRequestProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$displayPreparationRequestHash() =>
    r'1e15164f605e01d48f911f3c6502e2b052906c85';

final class DisplayPreparationRequestFamily extends $Family
    with $FunctionalFamilyOverride<Stream<DisplayPreparation?>, String> {
  DisplayPreparationRequestFamily._()
    : super(
        retry: _noAutomaticPreparationRetry,
        name: r'displayPreparationRequestProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DisplayPreparationRequestProvider call(String deviceId) =>
      DisplayPreparationRequestProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'displayPreparationRequestProvider';
}
