// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_slide_order_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SavedSlideOrderController)
final savedSlideOrderControllerProvider = SavedSlideOrderControllerFamily._();

final class SavedSlideOrderControllerProvider
    extends $NotifierProvider<SavedSlideOrderController, SavedSlideOrderState> {
  SavedSlideOrderControllerProvider._({
    required SavedSlideOrderControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'savedSlideOrderControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$savedSlideOrderControllerHash();

  @override
  String toString() {
    return r'savedSlideOrderControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SavedSlideOrderController create() => SavedSlideOrderController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedSlideOrderState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedSlideOrderState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedSlideOrderControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$savedSlideOrderControllerHash() =>
    r'f44e79db2158abee465140b5244cac79c6f74da3';

final class SavedSlideOrderControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SavedSlideOrderController,
          SavedSlideOrderState,
          SavedSlideOrderState,
          SavedSlideOrderState,
          String
        > {
  SavedSlideOrderControllerFamily._()
    : super(
        retry: null,
        name: r'savedSlideOrderControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SavedSlideOrderControllerProvider call(String scope) =>
      SavedSlideOrderControllerProvider._(argument: scope, from: this);

  @override
  String toString() => r'savedSlideOrderControllerProvider';
}

abstract class _$SavedSlideOrderController
    extends $Notifier<SavedSlideOrderState> {
  late final _$args = ref.$arg as String;
  String get scope => _$args;

  SavedSlideOrderState build(String scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SavedSlideOrderState, SavedSlideOrderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SavedSlideOrderState, SavedSlideOrderState>,
              SavedSlideOrderState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
