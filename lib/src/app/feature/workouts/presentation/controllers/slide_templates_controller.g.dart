// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_templates_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SlideTemplatesController)
final slideTemplatesControllerProvider = SlideTemplatesControllerFamily._();

final class SlideTemplatesControllerProvider
    extends
        $AsyncNotifierProvider<SlideTemplatesController, List<WorkoutModule>> {
  SlideTemplatesControllerProvider._({
    required SlideTemplatesControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'slideTemplatesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$slideTemplatesControllerHash();

  @override
  String toString() {
    return r'slideTemplatesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SlideTemplatesController create() => SlideTemplatesController();

  @override
  bool operator ==(Object other) {
    return other is SlideTemplatesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$slideTemplatesControllerHash() =>
    r'5a5ca4a7ebe2814002f008b19f5c8155a0b012d4';

final class SlideTemplatesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SlideTemplatesController,
          AsyncValue<List<WorkoutModule>>,
          List<WorkoutModule>,
          FutureOr<List<WorkoutModule>>,
          String
        > {
  SlideTemplatesControllerFamily._()
    : super(
        retry: null,
        name: r'slideTemplatesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SlideTemplatesControllerProvider call(String scope) =>
      SlideTemplatesControllerProvider._(argument: scope, from: this);

  @override
  String toString() => r'slideTemplatesControllerProvider';
}

abstract class _$SlideTemplatesController
    extends $AsyncNotifier<List<WorkoutModule>> {
  late final _$args = ref.$arg as String;
  String get scope => _$args;

  FutureOr<List<WorkoutModule>> build(String scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<WorkoutModule>>, List<WorkoutModule>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<WorkoutModule>>, List<WorkoutModule>>,
              AsyncValue<List<WorkoutModule>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
