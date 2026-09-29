import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/repositories/library_folder_repository.dart';
part 'library_folder_actions.g.dart';

class LibraryFolderActions {
  const LibraryFolderActions(this.repository);
  final LibraryFolderRepository repository;
  Stream<List<String>> watch(String owner) => repository.watch(owner);
  Future<void> create(String name) => repository.create(name);
  Future<void> rename(String name, String newName) =>
      repository.rename(name, newName);
  Future<void> remove(String name) => repository.remove(name);
}

@riverpod
LibraryFolderActions libraryFolderActions(Ref ref) =>
    LibraryFolderActions(ref.watch(libraryFolderRepositoryProvider));
