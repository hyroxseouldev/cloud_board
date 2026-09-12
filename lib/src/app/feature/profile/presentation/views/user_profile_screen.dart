import 'package:cloud_board/src/app/feature/profile/presentation/widgets/account_management_section.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
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
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppStyle.fullWidth + 48),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('프로필 설정', style: AppStyle.of(context).mainText),
                const SizedBox(height: 28),
                AsyncValueWidget<UserProfile>(
                  value: profileState,
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileSection(
                        child: Row(
                          children: [
                            _ProfileAvatar(
                              displayName: data.displayName,
                              photoUrl: data.photoUrl,
                              bytes: avatarBytes.value,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppStyle.of(context).subText3,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data.email,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '프로필 사진 변경',
                              onPressed: profileState.isLoading
                                  ? null
                                  : selectAvatar,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProfileSection(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('계정 정보', style: AppStyle.of(context).subText2),
                            const SizedBox(height: 20),
                            TextField(
                              controller: nameController,
                              enabled: !profileState.isLoading,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: '이름',
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: data.email,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: '이메일',
                                fillColor: Colors.white,
                                helperText: 'Google 계정 이메일은 여기서 변경할 수 없습니다.',
                                helperMaxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PartnerCard(profile: data),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(
                            AppStyle.of(context).primaryButtonHeight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppStyle.controlRadius,
                            ),
                          ),
                        ),
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
                                if (success && context.mounted) {
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
                const SizedBox(height: 24),
                const AccountManagementSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppStyle.cardRadius),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final endLabel = profile.pilotEndsAt == null
        ? '파일럿 기간 협의 중'
        : '${profile.pilotEndsAt!.year}.${profile.pilotEndsAt!.month.toString().padLeft(2, '0')}.${profile.pilotEndsAt!.day.toString().padLeft(2, '0')}까지';
    return _ProfileSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('이용 정보', style: AppStyle.of(context).subText2),
          const SizedBox(height: 20),
          _ProfileInfo(label: '등급', value: profile.partnerTier.label),
          _ProfileInfo(label: '이용 상태', value: profile.subscriptionStatus.label),
          _ProfileInfo(label: '연결 가능', value: '디스플레이 ${profile.displayLimit}대'),
          _ProfileInfo(label: '이용 기간', value: endLabel),
        ],
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
      radius: 32,
      foregroundImage: image,
      child: image == null
          ? Text(
              displayName.isEmpty
                  ? '?'
                  : displayName.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}
