// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SlideEditorController)
final slideEditorControllerProvider = SlideEditorControllerFamily._();

final class SlideEditorControllerProvider
    extends $NotifierProvider<SlideEditorController, SlideEditorState> {
  SlideEditorControllerProvider._({
    required SlideEditorControllerFamily super.from,
    required (String, WorkoutModule, String) super.argument,
  }) : super(
         retry: null,
         name: r'slideEditorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$slideEditorControllerHash();

  @override
  String toString() {
    return r'slideEditorControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  SlideEditorController create() => SlideEditorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlideEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlideEditorState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SlideEditorControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$slideEditorControllerHash() =>
    r'afe1c75c4503d9bfdca9b9e0e1a6d716ec2f33a3';

final class SlideEditorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SlideEditorController,
          SlideEditorState,
          SlideEditorState,
          SlideEditorState,
          (String, WorkoutModule, String)
        > {
  SlideEditorControllerFamily._()
    : super(
        retry: null,
        name: r'slideEditorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SlideEditorControllerProvider call(
    String workoutId,
    WorkoutModule original,
    String scope,
  ) => SlideEditorControllerProvider._(
    argument: (workoutId, original, scope),
    from: this,
  );

  @override
  String toString() => r'slideEditorControllerProvider';
}

abstract class _$SlideEditorController extends $Notifier<SlideEditorState> {
  late final _$args = ref.$arg as (String, WorkoutModule, String);
  String get workoutId => _$args.$1;
  WorkoutModule get original => _$args.$2;
  String get scope => _$args.$3;

  SlideEditorState build(
    String workoutId,
    WorkoutModule original,
    String scope,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SlideEditorState, SlideEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SlideEditorState, SlideEditorState>,
              SlideEditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(_$args.$1, _$args.$2, _$args.$3),
    );
  }
}
