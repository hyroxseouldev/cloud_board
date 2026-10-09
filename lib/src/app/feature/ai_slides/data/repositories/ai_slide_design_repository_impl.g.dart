// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slide_design_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiSlideDesignRepository)
final aiSlideDesignRepositoryProvider = AiSlideDesignRepositoryProvider._();

final class AiSlideDesignRepositoryProvider
    extends
        $FunctionalProvider<
          AiSlideDesignRepository,
          AiSlideDesignRepository,
          AiSlideDesignRepository
        >
    with $Provider<AiSlideDesignRepository> {
  AiSlideDesignRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSlideDesignRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSlideDesignRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiSlideDesignRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiSlideDesignRepository create(Ref ref) {
    return aiSlideDesignRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSlideDesignRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSlideDesignRepository>(value),
    );
  }
}

String _$aiSlideDesignRepositoryHash() =>
    r'fb78abaaeed3a9f2318806614363217caba01958';
