// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_templates_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SlideTemplateWrites)
final slideTemplateWritesProvider = SlideTemplateWritesFamily._();

final class SlideTemplateWritesProvider
    extends $NotifierProvider<SlideTemplateWrites, Set<String>> {
  SlideTemplateWritesProvider._({
    required SlideTemplateWritesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'slideTemplateWritesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$slideTemplateWritesHash();

  @override
  String toString() {
    return r'slideTemplateWritesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SlideTemplateWrites create() => SlideTemplateWrites();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SlideTemplateWritesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$slideTemplateWritesHash() =>
    r'00da9770dedf788c327a8ebef9d57b7fe1cc2b04';

final class SlideTemplateWritesFamily extends $Family
    with
        $ClassFamilyOverride<
          SlideTemplateWrites,
          Set<String>,
          Set<String>,
          Set<String>,
          String
        > {
  SlideTemplateWritesFamily._()
    : super(
        retry: null,
        name: r'slideTemplateWritesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SlideTemplateWritesProvider call(String scope) =>
      SlideTemplateWritesProvider._(argument: scope, from: this);

  @override
  String toString() => r'slideTemplateWritesProvider';
}

abstract class _$SlideTemplateWrites extends $Notifier<Set<String>> {
  late final _$args = ref.$arg as String;
  String get scope => _$args;

  Set<String> build(String scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(SlideTemplatesController)
final slideTemplatesControllerProvider = SlideTemplatesControllerFamily._();

final class SlideTemplatesControllerProvider
    extends
        $StreamNotifierProvider<SlideTemplatesController, List<WorkoutModule>> {
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
    r'b99b6397646defff2df53fa979c959454c7e0c6e';

final class SlideTemplatesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SlideTemplatesController,
          AsyncValue<List<WorkoutModule>>,
          List<WorkoutModule>,
          Stream<List<WorkoutModule>>,
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
    extends $StreamNotifier<List<WorkoutModule>> {
  late final _$args = ref.$arg as String;
  String get scope => _$args;

  Stream<List<WorkoutModule>> build(String scope);
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
