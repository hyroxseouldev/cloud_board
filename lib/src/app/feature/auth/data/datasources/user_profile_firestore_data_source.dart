import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileFirestoreDataSource {
  UserProfileFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> fetch(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    return snapshot.data();
  }

  Future<void> upsert(User user) =>
      _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '사용자',
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> update({
    required String userId,
    required String displayName,
    required String? photoUrl,
  }) => _firestore.collection('users').doc(userId).set({
    'uid': userId,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
