// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_preparation_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displayPreparationRepository)
final displayPreparationRepositoryProvider =
    DisplayPreparationRepositoryProvider._();

final class DisplayPreparationRepositoryProvider
    extends
        $FunctionalProvider<
          DisplayPreparationRepository,
          DisplayPreparationRepository,
          DisplayPreparationRepository
        >
    with $Provider<DisplayPreparationRepository> {
  DisplayPreparationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayPreparationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayPreparationRepositoryHash();

  @$internal
  @override
  $ProviderElement<DisplayPreparationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisplayPreparationRepository create(Ref ref) {
    return displayPreparationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayPreparationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayPreparationRepository>(value),
    );
  }
}

String _$displayPreparationRepositoryHash() =>
    r'6aebce04e1659442ba09d4ab37db8538257b457e';
