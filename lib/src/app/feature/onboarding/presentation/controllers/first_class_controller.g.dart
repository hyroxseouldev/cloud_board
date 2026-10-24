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

String _$firstClassScopeHash() => r'661421914f9e8120306b0925c9ad05c5df930144';

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
    r'6ca60fdafb69c4d18bafe60d59f936d40b90711c';

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
