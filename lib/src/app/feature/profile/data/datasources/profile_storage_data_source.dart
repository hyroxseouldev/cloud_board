import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class ProfileStorageDataSource {
  const ProfileStorageDataSource(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = extension.toLowerCase().replaceAll('.', '');
    final format = safeExtension == 'png' ? 'png' : 'jpeg';
    final managed = await managedUploadIfEnrolled(
      _storage.app,
      ownerId: userId,
      bytes: bytes,
      contentType: 'image/$format',
      purpose: 'profile',
    );
    if (managed != null) return managed;
    final reference = _storage.ref(
      'users/$userId/profile/avatar.$safeExtension',
    );
    await reference.putData(
      bytes,
      SettableMetadata(contentType: 'image/$format'),
    );
    return reference.getDownloadURL();
  }
}
