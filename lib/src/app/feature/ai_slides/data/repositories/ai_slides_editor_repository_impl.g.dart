// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_editor_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlidesDraftLocalDataSource)
final aiSlidesDraftLocalDataSourceProvider =
    AiSlidesDraftLocalDataSourceProvider._();

final class AiSlidesDraftLocalDataSourceProvider
    extends
        $FunctionalProvider<
          AiSlidesDraftLocalDataSource,
          AiSlidesDraftLocalDataSource,
          AiSlidesDraftLocalDataSource
        >
    with $Provider<AiSlidesDraftLocalDataSource> {
  AiSlidesDraftLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesDraftLocalDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesDraftLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<AiSlidesDraftLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiSlidesDraftLocalDataSource create(Ref ref) {
    return aiSlidesDraftLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlidesDraftLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlidesDraftLocalDataSource>(value),
    );
  }
}

String _$aiSlidesDraftLocalDataSourceHash() =>
    r'9486b39a2914ae2b1e37f43a67be8df9f8cd00f1';

@ProviderFor(aiSlidesEditorRepository)
final aiSlidesEditorRepositoryProvider = AiSlidesEditorRepositoryProvider._();

final class AiSlidesEditorRepositoryProvider
    extends
        $FunctionalProvider<
          AiSlidesEditorRepository,
          AiSlidesEditorRepository,
          AiSlidesEditorRepository
        >
    with $Provider<AiSlidesEditorRepository> {
  AiSlidesEditorRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesEditorRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesEditorRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiSlidesEditorRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiSlidesEditorRepository create(Ref ref) {
    return aiSlidesEditorRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlidesEditorRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlidesEditorRepository>(value),
    );
  }
}

String _$aiSlidesEditorRepositoryHash() =>
    r'e395e510a5953cdd824d64cb7d34aa7d442b893a';
