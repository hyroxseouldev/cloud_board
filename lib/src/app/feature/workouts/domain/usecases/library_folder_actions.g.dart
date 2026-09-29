// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_folder_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(libraryFolderActions)
final libraryFolderActionsProvider = LibraryFolderActionsProvider._();

final class LibraryFolderActionsProvider
    extends
        $FunctionalProvider<
          LibraryFolderActions,
          LibraryFolderActions,
          LibraryFolderActions
        >
    with $Provider<LibraryFolderActions> {
  LibraryFolderActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFolderActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFolderActionsHash();

  @$internal
  @override
  $ProviderElement<LibraryFolderActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryFolderActions create(Ref ref) {
    return libraryFolderActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryFolderActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryFolderActions>(value),
    );
  }
}

String _$libraryFolderActionsHash() =>
    r'c646599c7fe94bf66165b5f90b35c7d8d055338b';
