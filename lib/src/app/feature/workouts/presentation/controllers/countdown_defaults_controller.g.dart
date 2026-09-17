// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_defaults_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CountdownDefaultsController)
final countdownDefaultsControllerProvider =
    CountdownDefaultsControllerFamily._();

final class CountdownDefaultsControllerProvider
    extends
        $NotifierProvider<CountdownDefaultsController, AsyncValue<String?>> {
  CountdownDefaultsControllerProvider._({
    required CountdownDefaultsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'countdownDefaultsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$countdownDefaultsControllerHash();

  @override
  String toString() {
    return r'countdownDefaultsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CountdownDefaultsController create() => CountdownDefaultsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String?>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CountdownDefaultsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$countdownDefaultsControllerHash() =>
    r'fae73e8717f6ddc1b55f5be091fa309e465dfff6';

final class CountdownDefaultsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CountdownDefaultsController,
          AsyncValue<String?>,
          AsyncValue<String?>,
          AsyncValue<String?>,
          String
        > {
  CountdownDefaultsControllerFamily._()
    : super(
        retry: null,
        name: r'countdownDefaultsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CountdownDefaultsControllerProvider call(String ownerId) =>
      CountdownDefaultsControllerProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'countdownDefaultsControllerProvider';
}

abstract class _$CountdownDefaultsController
    extends $Notifier<AsyncValue<String?>> {
  late final _$args = ref.$arg as String;
  String get ownerId => _$args;

  AsyncValue<String?> build(String ownerId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(newWorkoutCountdownDefaults)
final newWorkoutCountdownDefaultsProvider =
    NewWorkoutCountdownDefaultsFamily._();

final class NewWorkoutCountdownDefaultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CountdownPreferences>,
          CountdownPreferences,
          FutureOr<CountdownPreferences>
        >
    with
        $FutureModifier<CountdownPreferences>,
        $FutureProvider<CountdownPreferences> {
  NewWorkoutCountdownDefaultsProvider._({
    required NewWorkoutCountdownDefaultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'newWorkoutCountdownDefaultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$newWorkoutCountdownDefaultsHash();

  @override
  String toString() {
    return r'newWorkoutCountdownDefaultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CountdownPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CountdownPreferences> create(Ref ref) {
    final argument = this.argument as String;
    return newWorkoutCountdownDefaults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NewWorkoutCountdownDefaultsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$newWorkoutCountdownDefaultsHash() =>
    r'cf5fffe4309b3ba5e3961c303ffbc12362bfe624';

final class NewWorkoutCountdownDefaultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CountdownPreferences>, String> {
  NewWorkoutCountdownDefaultsFamily._()
    : super(
        retry: null,
        name: r'newWorkoutCountdownDefaultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NewWorkoutCountdownDefaultsProvider call(String ownerId) =>
      NewWorkoutCountdownDefaultsProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'newWorkoutCountdownDefaultsProvider';
}
