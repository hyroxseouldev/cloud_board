// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exploration_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(explorationRepository)
final explorationRepositoryProvider = ExplorationRepositoryProvider._();

final class ExplorationRepositoryProvider
    extends
        $FunctionalProvider<
          ExplorationRepository,
          ExplorationRepository,
          ExplorationRepository
        >
    with $Provider<ExplorationRepository> {
  ExplorationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'explorationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$explorationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ExplorationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExplorationRepository create(Ref ref) {
    return explorationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExplorationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExplorationRepository>(value),
    );
  }
}

String _$explorationRepositoryHash() =>
    r'675d0dfa3256e17492fd21cb24d1d629075012d4';
