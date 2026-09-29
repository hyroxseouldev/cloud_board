// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_folder_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(libraryFolderRepository)
final libraryFolderRepositoryProvider = LibraryFolderRepositoryProvider._();

final class LibraryFolderRepositoryProvider
    extends
        $FunctionalProvider<
          LibraryFolderRepository,
          LibraryFolderRepository,
          LibraryFolderRepository
        >
    with $Provider<LibraryFolderRepository> {
  LibraryFolderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFolderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFolderRepositoryHash();

  @$internal
  @override
  $ProviderElement<LibraryFolderRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryFolderRepository create(Ref ref) {
    return libraryFolderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryFolderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryFolderRepository>(value),
    );
  }
}

String _$libraryFolderRepositoryHash() =>
    r'c23cf4ac3cbbf90a5f41e6546e4a7c90a8dcfdf5';
