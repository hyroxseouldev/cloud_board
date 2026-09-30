// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_news_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateNewsRepository)
final updateNewsRepositoryProvider = UpdateNewsRepositoryProvider._();

final class UpdateNewsRepositoryProvider
    extends
        $FunctionalProvider<
          UpdateNewsRepository,
          UpdateNewsRepository,
          UpdateNewsRepository
        >
    with $Provider<UpdateNewsRepository> {
  UpdateNewsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNewsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNewsRepositoryHash();

  @$internal
  @override
  $ProviderElement<UpdateNewsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateNewsRepository create(Ref ref) {
    return updateNewsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateNewsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateNewsRepository>(value),
    );
  }
}

String _$updateNewsRepositoryHash() =>
    r'f2faec50ec7e6830be38c48129bc28f970c01be5';
