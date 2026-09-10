// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_rehearsal_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SlideRehearsalController)
final slideRehearsalControllerProvider = SlideRehearsalControllerFamily._();

final class SlideRehearsalControllerProvider
    extends $NotifierProvider<SlideRehearsalController, RehearsalState> {
  SlideRehearsalControllerProvider._({
    required SlideRehearsalControllerFamily super.from,
    required WorkoutModule super.argument,
  }) : super(
         retry: null,
         name: r'slideRehearsalControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$slideRehearsalControllerHash();

  @override
  String toString() {
    return r'slideRehearsalControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SlideRehearsalController create() => SlideRehearsalController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RehearsalState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RehearsalState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SlideRehearsalControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$slideRehearsalControllerHash() =>
    r'2c0949c10784f0f11fb5ba6d9d58acdec86c06a0';

final class SlideRehearsalControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SlideRehearsalController,
          RehearsalState,
          RehearsalState,
          RehearsalState,
          WorkoutModule
        > {
  SlideRehearsalControllerFamily._()
    : super(
        retry: null,
        name: r'slideRehearsalControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SlideRehearsalControllerProvider call(WorkoutModule module) =>
      SlideRehearsalControllerProvider._(argument: module, from: this);

  @override
  String toString() => r'slideRehearsalControllerProvider';
}

abstract class _$SlideRehearsalController extends $Notifier<RehearsalState> {
  late final _$args = ref.$arg as WorkoutModule;
  WorkoutModule get module => _$args;

  RehearsalState build(WorkoutModule module);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RehearsalState, RehearsalState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RehearsalState, RehearsalState>,
              RehearsalState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
