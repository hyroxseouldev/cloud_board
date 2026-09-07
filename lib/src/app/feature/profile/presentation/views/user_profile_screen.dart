import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';

class UserProfileScreen extends HookConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileControllerProvider);
    final nameController = useTextEditingController();
    final avatarBytes = useState<Uint8List?>(null);
    final avatarExtension = useState<String?>(null);
    final initializedUserId = useRef<String?>(null);
    final hasSubmitted = useRef(false);
    final profile = profileState.value;

    useEffect(() {
      if (profile != null && initializedUserId.value != profile.id) {
        nameController.text = profile.displayName;
        initializedUserId.value = profile.id;
      }
      return null;
    }, [profile?.id]);

    ref.listen(userProfileControllerProvider, (previous, next) {
      if (!hasSubmitted.value ||
          previous?.isLoading != true ||
          next.isLoading) {
        return;
      }
      hasSubmitted.value = false;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            next.hasError ? '프로필을 저장하지 못했습니다: ${next.error}' : '프로필을 저장했습니다.',
          ),
          backgroundColor: next.hasError ? Colors.red.shade800 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    Future<void> selectAvatar() async {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 88,
      );
      if (image == null) return;
      avatarBytes.value = await image.readAsBytes();
      avatarExtension.value = image.name.split('.').last;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AsyncValueWidget<UserProfile>(
        value: profileState,
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _ProfileAvatar(
                              displayName: data.displayName,
                              photoUrl: data.photoUrl,
                              bytes: avatarBytes.value,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: IconButton.filled(
                                tooltip: '프로필 사진 변경',
                                onPressed: profileState.isLoading
                                    ? null
                                    : selectAvatar,
                                icon: const Icon(Icons.photo_camera_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _PartnerCard(profile: data),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        enabled: !profileState.isLoading,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: data.email,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          prefixIcon: Icon(Icons.email_outlined),
                          helperText: 'Google 계정 이메일은 여기서 변경할 수 없습니다.',
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: profileState.isLoading
                            ? null
                            : () async {
                                hasSubmitted.value = true;
                                final success = await ref
                                    .read(
                                      userProfileControllerProvider.notifier,
                                    )
                                    .updateProfile(
                                      displayName: nameController.text,
                                      avatarBytes: avatarBytes.value,
                                      avatarExtension: avatarExtension.value,
                                    );
                                if (success) {
                                  avatarBytes.value = null;
                                  avatarExtension.value = null;
                                }
                              },
                        icon: profileState.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          profileState.isLoading ? '저장 중...' : '변경사항 저장',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final endLabel = profile.pilotEndsAt == null
        ? '파일럿 기간 협의 중'
        : '${profile.pilotEndsAt!.year}.${profile.pilotEndsAt!.month.toString().padLeft(2, '0')}.${profile.pilotEndsAt!.day.toString().padLeft(2, '0')}까지';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  profile.partnerTier.label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'CloudBoard 초기 제품 개발에 참여하는 공식 파트너입니다.',
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PartnerChip(label: profile.subscriptionStatus.label),
                _PartnerChip(label: '디스플레이 ${profile.displayLimit}대'),
                _PartnerChip(label: endLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerChip extends StatelessWidget {
  const _PartnerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.photoUrl,
    required this.bytes,
  });

  final String displayName;
  final String? photoUrl;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final image = bytes != null
        ? MemoryImage(bytes!) as ImageProvider
        : photoUrl != null && photoUrl!.isNotEmpty
        ? NetworkImage(photoUrl!)
        : null;
    return CircleAvatar(
      radius: 58,
      foregroundImage: image,
      child: image == null
          ? Text(
              displayName.isEmpty
                  ? '?'
                  : displayName.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}
