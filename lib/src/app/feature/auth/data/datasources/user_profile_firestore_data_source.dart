import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileFirestoreDataSource {
  UserProfileFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> fetch(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final entitlement = await _firestore
        .collection('subscriptionEntitlements')
        .doc(userId)
        .get();
    final data = snapshot.data();
    final access = entitlement.data();
    if (access == null || access['managed'] != true) {
      return {
        ...?data,
        'partnerTier': 'free',
        'subscriptionPlan': 'free',
        'subscriptionStatus': 'free',
      };
    }
    final validUntil = (access['validUntilMs'] as num?)?.toInt() ?? 0;
    final valid = validUntil > DateTime.now().millisecondsSinceEpoch;
    final status = access['status'];
    return {
      ...?data,
      'partnerTier': !valid
          ? 'free'
          : status == 'trialing'
          ? 'trial'
          : 'pro',
      'subscriptionPlan': valid ? 'cloudboard_pro' : 'free',
      'subscriptionStatus': !valid
          ? 'canceled'
          : status == 'trialing'
          ? 'trialing'
          : status == 'past_due'
          ? 'pastDue'
          : 'active',
      'displayLimit': access['displayLimit'] ?? 3,
    };
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
    // Subscription fields are written only by the verified billing backend.
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
