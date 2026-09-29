import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/library_folder_data_source.dart';
part 'library_folder_repository.g.dart';

class LibraryFolderRepository {
  const LibraryFolderRepository(this.source);
  final LibraryFolderDataSource source;
  Stream<List<String>> watch(String owner) => source.watch(owner);
  Future<void> create(String name) => source.mutate('create', name);
  Future<void> rename(String name, String newName) =>
      source.mutate('rename', name, newName: newName);
  Future<void> remove(String name) => source.mutate('remove', name);
}

@riverpod
LibraryFolderRepository libraryFolderRepository(Ref ref) =>
    LibraryFolderRepository(
      LibraryFolderDataSource(
        FirebaseFirestore.instance,
        FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
      ),
    );
