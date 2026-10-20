import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/saved_slide_order.dart';

/// Optional, independently owned profile field. Existing profile writers merge
/// their fields; slide DTOs/callables and their server-only permissions stay intact.
class SavedSlideOrderDataSource {
  SavedSlideOrderDataSource(this.firestore);
  final FirebaseFirestore firestore;
  static const field = 'savedSlideOrder';

  Stream<List<String>> watch(String uid) => firestore
      .doc('users/$uid')
      .snapshots()
      .map((snapshot) => readSavedSlideOrder(snapshot.data()?[field]));

  Future<List<String>> load(String uid) async => readSavedSlideOrder(
    (await firestore
            .doc('users/$uid')
            .get(const GetOptions(source: Source.server)))
        .data()?[field],
  );

  Future<List<String>> reconcile(
    String uid,
    List<String> knownIds, {
    SavedSlideMove? move,
    required void Function() checkAccount,
  }) => firestore.runTransaction((transaction) async {
    checkAccount();
    final profile = firestore.doc('users/$uid');
    final snapshot = await transaction.get(profile);
    if (!snapshot.exists) {
      throw const LibraryFailure('계정 정보를 불러온 뒤 다시 시도해 주세요.');
    }
    final stored = readSavedSlideOrder(snapshot.data()?[field]);
    final candidates = {...stored, ...knownIds.where(isSavedSlideId)}.toList();
    // Re-read every candidate inside the transaction. A concurrent tombstone
    // retries the transaction instead of reintroducing a deleted ID. Additions
    // not in this snapshot append on the next library stream event.
    final items = await Future.wait(
      candidates.map(
        (id) => transaction.get(firestore.doc('users/$uid/slideTemplates/$id')),
      ),
    );
    final live = [
      for (var i = 0; i < items.length; i++)
        if (items[i].exists && items[i].data()?['deleted'] != true)
          candidates[i],
    ];
    final next = reconcileSavedSlideOrder(stored, live, move: move);
    checkAccount();
    if (!const ListEquality<String>().equals(stored, next)) {
      transaction.update(profile, {field: next});
    }
    return next;
  });
}
