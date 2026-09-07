import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileFirestoreDataSource {
  UserProfileFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> fetch(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    return snapshot.data();
  }

  Future<void> upsert(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    await reference.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? '사용자',
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final snapshot = await reference.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final defaults = <String, Object?>{};
    if (!data.containsKey('partnerTier')) defaults['partnerTier'] = 'pilot';
    if (!data.containsKey('subscriptionPlan')) {
      defaults['subscriptionPlan'] = 'cloudboard_pro';
    }
    if (!data.containsKey('subscriptionStatus')) {
      defaults['subscriptionStatus'] = 'free';
    }
    if (!data.containsKey('displayLimit')) defaults['displayLimit'] = 3;
    if (!data.containsKey('pilotStartedAt')) {
      defaults['pilotStartedAt'] = FieldValue.serverTimestamp();
    }
    if (defaults.isNotEmpty) {
      await reference.set(defaults, SetOptions(merge: true));
    }
  }

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
