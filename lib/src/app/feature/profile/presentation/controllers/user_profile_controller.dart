import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/user_profile_actions.dart';

part 'user_profile_controller.g.dart';

@riverpod
class UserProfileController extends _$UserProfileController {
  @override
  Future<UserProfile> build() => ref.watch(getUserProfileProvider).call();

  Future<bool> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) async {
    final name = displayName.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      if (name.isEmpty) throw ArgumentError('이름을 입력해 주세요.');
      return ref
          .read(updateUserProfileProvider)
          .call(
            displayName: name,
            avatarBytes: avatarBytes,
            avatarExtension: avatarExtension,
          );
    });
    return !state.hasError;
  }
}
