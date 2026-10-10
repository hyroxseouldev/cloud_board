// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exploration_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExplorationController)
final explorationControllerProvider = ExplorationControllerProvider._();

final class ExplorationControllerProvider
    extends $AsyncNotifierProvider<ExplorationController, ExplorationProgress> {
  ExplorationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'explorationControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$explorationControllerHash();

  @$internal
  @override
  ExplorationController create() => ExplorationController();
}

String _$explorationControllerHash() =>
    r'6bff440048d423c8667a40d7252eb1c5a5743614';

abstract class _$ExplorationController
    extends $AsyncNotifier<ExplorationProgress> {
  FutureOr<ExplorationProgress> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ExplorationProgress>, ExplorationProgress>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ExplorationProgress>, ExplorationProgress>,
              AsyncValue<ExplorationProgress>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
