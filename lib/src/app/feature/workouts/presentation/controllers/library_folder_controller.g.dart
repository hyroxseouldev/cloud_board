// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_folder_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(libraryFolders)
final libraryFoldersProvider = LibraryFoldersProvider._();

final class LibraryFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          Stream<List<String>>
        >
    with $FutureModifier<List<String>>, $StreamProvider<List<String>> {
  LibraryFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFoldersHash();

  @$internal
  @override
  $StreamProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>> create(Ref ref) {
    return libraryFolders(ref);
  }
}

String _$libraryFoldersHash() => r'e99c67c47ab37ff446500da74db814699e27a02f';

@ProviderFor(LibraryFolderController)
final libraryFolderControllerProvider = LibraryFolderControllerProvider._();

final class LibraryFolderControllerProvider
    extends $NotifierProvider<LibraryFolderController, AsyncValue<void>> {
  LibraryFolderControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFolderControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFolderControllerHash();

  @$internal
  @override
  LibraryFolderController create() => LibraryFolderController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$libraryFolderControllerHash() =>
    r'6385811b6d87275f02fbb24bd28cb6020d8314bb';

abstract class _$LibraryFolderController extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
