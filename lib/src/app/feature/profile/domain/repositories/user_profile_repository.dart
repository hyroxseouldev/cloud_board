import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile> getProfile();

  Future<UserProfile> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarExtension,
  });
}
