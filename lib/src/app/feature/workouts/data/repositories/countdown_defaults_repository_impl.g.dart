// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_defaults_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(countdownDefaultsRepository)
final countdownDefaultsRepositoryProvider =
    CountdownDefaultsRepositoryProvider._();

final class CountdownDefaultsRepositoryProvider
    extends
        $FunctionalProvider<
          CountdownDefaultsRepository,
          CountdownDefaultsRepository,
          CountdownDefaultsRepository
        >
    with $Provider<CountdownDefaultsRepository> {
  CountdownDefaultsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'countdownDefaultsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$countdownDefaultsRepositoryHash();

  @$internal
  @override
  $ProviderElement<CountdownDefaultsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CountdownDefaultsRepository create(Ref ref) {
    return countdownDefaultsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CountdownDefaultsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CountdownDefaultsRepository>(value),
    );
  }
}

String _$countdownDefaultsRepositoryHash() =>
    r'235ed27e3cfbe858efcfe8fbed5a4fc13110d311';
