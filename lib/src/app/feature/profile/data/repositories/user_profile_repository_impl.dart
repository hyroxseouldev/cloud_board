import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/data/datasources/firebase_auth_data_source.dart';
import '../../../auth/data/datasources/user_profile_firestore_data_source.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/profile_storage_data_source.dart';
import '../models/user_profile_model.dart';

part 'user_profile_repository_impl.g.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl(this._auth, this._firestore, this._storage);

  final FirebaseAuthDataSource _auth;
  final UserProfileFirestoreDataSource _firestore;
  final ProfileStorageDataSource _storage;

  @override
  Future<UserProfile> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final data = await _firestore.fetch(user.uid);
    return UserProfileModel(
      uid: user.uid,
      email: data?['email'] as String? ?? user.email ?? '',
      displayName: data?['displayName'] as String? ?? user.displayName ?? '사용자',
      photoUrl: data?['photoUrl'] as String? ?? user.photoURL,
    ).toEntity();
  }

  @override
  Future<UserProfile> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    var photoUrl = user.photoURL;
    if (avatarBytes != null) {
      photoUrl = await _storage.uploadAvatar(
        userId: user.uid,
        bytes: avatarBytes,
        extension: avatarExtension ?? 'jpg',
      );
    }
    await _auth.updateProfile(displayName: displayName, photoUrl: photoUrl);
    await _firestore.update(
      userId: user.uid,
      displayName: displayName,
      photoUrl: photoUrl,
    );
    return UserProfile(
      id: user.uid,
      email: user.email ?? '',
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }
}

@riverpod
UserProfileRepository userProfileRepository(Ref ref) =>
    UserProfileRepositoryImpl(
      ref.watch(firebaseAuthDataSourceProvider),
      UserProfileFirestoreDataSource(FirebaseFirestore.instance),
      ProfileStorageDataSource(FirebaseStorage.instance),
    );
