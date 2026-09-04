import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileFirestoreDataSource {
  UserProfileFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> upsert(User user) =>
      _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '사용자',
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
