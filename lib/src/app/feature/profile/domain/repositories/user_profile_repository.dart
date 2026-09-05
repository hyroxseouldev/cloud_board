import 'dart:typed_data';

import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile> getProfile();

  Future<UserProfile> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarExtension,
  });
}
