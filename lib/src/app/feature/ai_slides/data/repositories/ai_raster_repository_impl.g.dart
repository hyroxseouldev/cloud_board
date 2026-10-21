// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_raster_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiRasterRepository)
final aiRasterRepositoryProvider = AiRasterRepositoryProvider._();

final class AiRasterRepositoryProvider
    extends
        $FunctionalProvider<
          AiRasterRepository?,
          AiRasterRepository?,
          AiRasterRepository?
        >
    with $Provider<AiRasterRepository?> {
  AiRasterRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiRasterRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiRasterRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiRasterRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiRasterRepository? create(Ref ref) {
    return aiRasterRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiRasterRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiRasterRepository?>(value),
    );
  }
}

String _$aiRasterRepositoryHash() =>
    r'acc210209fda08043f377a11cc926d28e1fec142';
