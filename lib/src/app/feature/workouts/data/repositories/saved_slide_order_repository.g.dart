// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_slide_order_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(savedSlideOrderRepository)
final savedSlideOrderRepositoryProvider = SavedSlideOrderRepositoryProvider._();

final class SavedSlideOrderRepositoryProvider
    extends
        $FunctionalProvider<
          SavedSlideOrderRepository,
          SavedSlideOrderRepository,
          SavedSlideOrderRepository
        >
    with $Provider<SavedSlideOrderRepository> {
  SavedSlideOrderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedSlideOrderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedSlideOrderRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedSlideOrderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedSlideOrderRepository create(Ref ref) {
    return savedSlideOrderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedSlideOrderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedSlideOrderRepository>(value),
    );
  }
}

String _$savedSlideOrderRepositoryHash() =>
    r'0b702de81c747f1ae350f2084b24e957d490bc49';
