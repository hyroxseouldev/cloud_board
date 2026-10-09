// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'first_class_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firstClassScope)
final firstClassScopeProvider = FirstClassScopeProvider._();

final class FirstClassScopeProvider
    extends
        $FunctionalProvider<
          AsyncValue<FirstClassScope?>,
          FirstClassScope?,
          FutureOr<FirstClassScope?>
        >
    with $FutureModifier<FirstClassScope?>, $FutureProvider<FirstClassScope?> {
  FirstClassScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstClassScopeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstClassScopeHash();

  @$internal
  @override
  $FutureProviderElement<FirstClassScope?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FirstClassScope?> create(Ref ref) {
    return firstClassScope(ref);
  }
}

String _$firstClassScopeHash() => r'911b4959025c2e3c959961e200d40f5038e50d67';

@ProviderFor(FirstClassController)
final firstClassControllerProvider = FirstClassControllerProvider._();

final class FirstClassControllerProvider
    extends $AsyncNotifierProvider<FirstClassController, FirstClassProgress?> {
  FirstClassControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstClassControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstClassControllerHash();

  @$internal
  @override
  FirstClassController create() => FirstClassController();
}

String _$firstClassControllerHash() =>
    r'e46b01273e96f68c8bc9bd344c3e3152b9a92674';

abstract class _$FirstClassController
    extends $AsyncNotifier<FirstClassProgress?> {
  FutureOr<FirstClassProgress?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<FirstClassProgress?>, FirstClassProgress?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FirstClassProgress?>, FirstClassProgress?>,
              AsyncValue<FirstClassProgress?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
