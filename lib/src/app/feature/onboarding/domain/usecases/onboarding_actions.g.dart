// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(onboardingActions)
final onboardingActionsProvider = OnboardingActionsProvider._();

final class OnboardingActionsProvider
    extends
        $FunctionalProvider<
          OnboardingActions,
          OnboardingActions,
          OnboardingActions
        >
    with $Provider<OnboardingActions> {
  OnboardingActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingActionsHash();

  @$internal
  @override
  $ProviderElement<OnboardingActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OnboardingActions create(Ref ref) {
    return onboardingActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingActions>(value),
    );
  }
}

String _$onboardingActionsHash() => r'5ec0f5a1bd31d20b85195ff21b0915baf0d15996';
