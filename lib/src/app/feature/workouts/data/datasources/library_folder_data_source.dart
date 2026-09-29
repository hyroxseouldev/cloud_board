import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LibraryFolderDataSource {
  const LibraryFolderDataSource(this.firestore, this.functions);
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  Stream<List<String>> watch(String owner) => firestore
      .collection('users/$owner/libraryFolders')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => d.data()['name']).whereType<String>().toList()
              ..sort(),
      );
  Future<void> mutate(String action, String name, {String? newName}) async {
    await functions
        .httpsCallable(
          'manageLibraryFolder',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call({'action': action, 'name': name, 'newName': ?newName});
  }
}
