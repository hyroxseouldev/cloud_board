import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SlideLibraryDataSource {
  SlideLibraryDataSource(this.firestore, this.functions);
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String kind,
  ) => firestore.collection(
    'users/$uid/slide${kind == 'templates' ? 'Templates' : 'Styles'}',
  );

  List<Map<String, dynamic>> _decode(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .where((doc) => doc.data()['deleted'] != true)
      .map((doc) => Map<String, dynamic>.from(doc.data()['value'] as Map))
      .toList();

  Stream<List<Map<String, dynamic>>> watch(String uid, String kind) =>
      _collection(uid, kind).snapshots().map(_decode);

  Future<List<Map<String, dynamic>>> load(String uid, String kind) async =>
      _decode(await _collection(uid, kind).get());

  Future<void> mutate(
    String uid,
    String kind,
    List<Map<String, dynamic>> changes, {
    bool migration = false,
  }) async {
    await functions.httpsCallable('updateSlideLibrary').call({
      'ownerId': uid,
      'kind': kind,
      'changes': changes,
      'migration': migration,
    });
  }
}
