// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

final class OnboardingControllerProvider
    extends $AsyncNotifierProvider<OnboardingController, CenterOnboarding> {
  OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();
}

String _$onboardingControllerHash() =>
    r'b51701da037f7f8ff3aacafada5b5287e306b810';

abstract class _$OnboardingController extends $AsyncNotifier<CenterOnboarding> {
  FutureOr<CenterOnboarding> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<CenterOnboarding>, CenterOnboarding>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CenterOnboarding>, CenterOnboarding>,
              AsyncValue<CenterOnboarding>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Kept alive only by the current onboarding view, never persisted across launch.
/// A returning account's load does not create a new activation celebration.

@ProviderFor(OnboardingCompletion)
final onboardingCompletionProvider = OnboardingCompletionProvider._();

/// Kept alive only by the current onboarding view, never persisted across launch.
/// A returning account's load does not create a new activation celebration.
final class OnboardingCompletionProvider
    extends $NotifierProvider<OnboardingCompletion, bool> {
  /// Kept alive only by the current onboarding view, never persisted across launch.
  /// A returning account's load does not create a new activation celebration.
  OnboardingCompletionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingCompletionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingCompletionHash();

  @$internal
  @override
  OnboardingCompletion create() => OnboardingCompletion();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$onboardingCompletionHash() =>
    r'd6846c56407dcffdca5b1c448a5490a3b2491663';

/// Kept alive only by the current onboarding view, never persisted across launch.
/// A returning account's load does not create a new activation celebration.

abstract class _$OnboardingCompletion extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(OnboardingAction)
final onboardingActionProvider = OnboardingActionProvider._();

final class OnboardingActionProvider
    extends $NotifierProvider<OnboardingAction, AsyncValue<void>> {
  OnboardingActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingActionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingActionHash();

  @$internal
  @override
  OnboardingAction create() => OnboardingAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$onboardingActionHash() => r'043b143a447471221990638b12874c8697c17491';

abstract class _$OnboardingAction extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(onboardingRequired)
final onboardingRequiredProvider = OnboardingRequiredProvider._();

final class OnboardingRequiredProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  OnboardingRequiredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingRequiredProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingRequiredHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return onboardingRequired(ref);
  }
}

String _$onboardingRequiredHash() =>
    r'c97a04398ac53527ef067be9246000349352d164';
