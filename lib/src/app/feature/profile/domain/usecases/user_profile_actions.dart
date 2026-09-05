import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/user_profile_repository_impl.dart';
import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

part 'user_profile_actions.g.dart';

class GetUserProfile {
  const GetUserProfile(this._repository);
  final UserProfileRepository _repository;
  Future<UserProfile> call() => _repository.getProfile();
}

class UpdateUserProfile {
  const UpdateUserProfile(this._repository);
  final UserProfileRepository _repository;
  Future<UserProfile> call({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) => _repository.updateProfile(
    displayName: displayName,
    avatarBytes: avatarBytes,
    avatarExtension: avatarExtension,
  );
}

@riverpod
GetUserProfile getUserProfile(Ref ref) =>
    GetUserProfile(ref.watch(userProfileRepositoryProvider));

@riverpod
UpdateUserProfile updateUserProfile(Ref ref) =>
    UpdateUserProfile(ref.watch(userProfileRepositoryProvider));
