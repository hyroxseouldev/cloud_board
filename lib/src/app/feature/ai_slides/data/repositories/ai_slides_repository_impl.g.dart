// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlidesRepository)
final aiSlidesRepositoryProvider = AiSlidesRepositoryProvider._();

final class AiSlidesRepositoryProvider
    extends
        $FunctionalProvider<
          AiSlidesRepository,
          AiSlidesRepository,
          AiSlidesRepository
        >
    with $Provider<AiSlidesRepository> {
  AiSlidesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlidesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlidesRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiSlidesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiSlidesRepository create(Ref ref) {
    return aiSlidesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlidesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlidesRepository>(value),
    );
  }
}

String _$aiSlidesRepositoryHash() =>
    r'e2401af7b7873599f7a1ec6d62f74bdbfbd926e5';
