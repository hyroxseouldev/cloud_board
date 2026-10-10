// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starter_workout_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StarterWorkoutController)
final starterWorkoutControllerProvider = StarterWorkoutControllerProvider._();

final class StarterWorkoutControllerProvider
    extends $NotifierProvider<StarterWorkoutController, AsyncValue<String?>> {
  StarterWorkoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'starterWorkoutControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$starterWorkoutControllerHash();

  @$internal
  @override
  StarterWorkoutController create() => StarterWorkoutController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String?>>(value),
    );
  }
}

String _$starterWorkoutControllerHash() =>
    r'c962bb8249d6482670e22b0f4d1a0ba94ef9d939';

abstract class _$StarterWorkoutController
    extends $Notifier<AsyncValue<String?>> {
  AsyncValue<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, AsyncValue<String?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, AsyncValue<String?>>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
