import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StoreBrandStorageDataSource {
  const StoreBrandStorageDataSource(this._storage, this._auth);

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Future<String> upload({
    required Uint8List bytes,
    required String extension,
    required String purpose,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final normalized = extension.toLowerCase().replaceAll('.', '');
    final safeExtension = {'png', 'webp', 'gif'}.contains(normalized)
        ? normalized
        : 'jpg';
    final reference = _storage.ref(
      'users/${user.uid}/brand/$purpose-${DateTime.now().microsecondsSinceEpoch}.$safeExtension',
    );
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: safeExtension == 'jpg'
            ? 'image/jpeg'
            : 'image/$safeExtension',
      ),
    );
    return reference.getDownloadURL();
  }
}
