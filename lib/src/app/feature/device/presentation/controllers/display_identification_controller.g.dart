// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_identification_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DisplayIdentificationController)
final displayIdentificationControllerProvider =
    DisplayIdentificationControllerFamily._();

final class DisplayIdentificationControllerProvider
    extends
        $NotifierProvider<
          DisplayIdentificationController,
          AsyncValue<DisplayIdentification?>
        > {
  DisplayIdentificationControllerProvider._({
    required DisplayIdentificationControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'displayIdentificationControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$displayIdentificationControllerHash();

  @override
  String toString() {
    return r'displayIdentificationControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DisplayIdentificationController create() => DisplayIdentificationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<DisplayIdentification?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DisplayIdentification?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayIdentificationControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$displayIdentificationControllerHash() =>
    r'd3f33c9388c60ffa92d577138ca63b68e04f7cc9';

final class DisplayIdentificationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DisplayIdentificationController,
          AsyncValue<DisplayIdentification?>,
          AsyncValue<DisplayIdentification?>,
          AsyncValue<DisplayIdentification?>,
          String
        > {
  DisplayIdentificationControllerFamily._()
    : super(
        retry: null,
        name: r'displayIdentificationControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DisplayIdentificationControllerProvider call(String deviceId) =>
      DisplayIdentificationControllerProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'displayIdentificationControllerProvider';
}

abstract class _$DisplayIdentificationController
    extends $Notifier<AsyncValue<DisplayIdentification?>> {
  late final _$args = ref.$arg as String;
  String get deviceId => _$args;

  AsyncValue<DisplayIdentification?> build(String deviceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DisplayIdentification?>,
              AsyncValue<DisplayIdentification?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DisplayIdentification?>,
                AsyncValue<DisplayIdentification?>
              >,
              AsyncValue<DisplayIdentification?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
