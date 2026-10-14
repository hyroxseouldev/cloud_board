import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/account_deletion_controller.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/widgets/account_management_section.dart';

class UserProfileScreen extends HookConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useOnAppLifecycleStateChange((previous, next) {
      if (next == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent == true) {
        ref.invalidate(userProfileControllerProvider);
      }
    });
    final profile = ref.watch(userProfileControllerProvider);
    final uid = ref.watch(authStateProvider).value?.id;
    final authAction = ref.watch(authControllerProvider);
    final deletion = ref.watch(accountDeletionControllerProvider);
    final onboarding = ref.watch(onboardingControllerProvider);
    final phoneVerified =
        !onboarding.isLoading &&
        !onboarding.hasError &&
        onboarding.value?.phoneRequired == false &&
        (onboarding.value?.storeId.isNotEmpty ?? false);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Text('프로필'),
        centerTitle: true,
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: _ProfileBody(
        child: AsyncValueWidget<UserProfile>(
          value: profile.hasValue && profile.value?.id != uid
              ? const AsyncLoading()
              : profile,
          onRetry: () => ref.invalidate(userProfileControllerProvider),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: _ProfileAvatar(
                  displayName: data.displayName,
                  photoUrl: data.photoUrl,
                  tooltip: '프로필 수정',
                  onPressed: () => context.push('/profile/edit'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: -0.24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/profile/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('이름·사진 수정'),
                ),
              ),
              const SizedBox(height: 24),
              _ProfileGroup(
                title: '계정',
                children: [
                  _ProfileInfo(
                    icon: Icons.mail_outline_rounded,
                    label: '이메일',
                    value: data.email,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileGroup(
                title: '센터',
                children: [
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(phoneVerified ? '센터 정보 · 선택' : '휴대폰 인증하기'),
                        if (phoneVerified)
                          const Tooltip(
                            message: '휴대폰 인증 완료',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 20,
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      onboarding.isLoading
                          ? '인증·센터 정보를 확인하고 있습니다'
                          : onboarding.hasError
                          ? '인증 정보를 확인하지 못했습니다 · 센터 정보에서 다시 확인'
                          : phoneVerified
                          ? '휴대폰 인증 완료 · 센터 정보 수정'
                          : 'Free 플랜을 사용하려면 휴대폰 인증을 완료해 주세요.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(
                      phoneVerified
                          ? '/onboarding?edit=true'
                          : '/onboarding?verify=true',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileGroup(
                title: '이용 정보',
                children: [
                  ListTile(
                    leading: const Icon(Icons.credit_card_rounded),
                    title: const Text('내 구독 관리'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/subscription'),
                  ),
                  _ProfileInfo(
                    icon: Icons.workspace_premium_outlined,
                    label: '구독',
                    value: data.planLabel,
                  ),
                  _ProfileInfo(
                    icon: Icons.check_circle_outline_rounded,
                    label: '이용 상태',
                    value: data.statusLabel,
                  ),
                  _ProfileInfo(
                    icon: Icons.connected_tv_rounded,
                    label: '연결 가능',
                    value: data.displayLimitLabel,
                  ),
                  _ProfileInfo(
                    icon: Icons.calendar_today_outlined,
                    label: '이용 기간',
                    value: _endLabel(data),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const AccountManagementSection(),
              const SizedBox(height: 16),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('로그아웃'),
                  trailing: authAction.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !authAction.isLoading && !deletion.isLoading,
                  onTap: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditUserProfileScreen extends HookConsumerWidget {
  const EditUserProfileScreen({super.key, this.guard});
  final ExitGuard? guard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileControllerProvider);
    final nameController = useTextEditingController();
    useListenable(nameController);
    final exitGuard = useMemoized(() => guard ?? ExitGuard(), [guard]);
    final avatarBytes = useState<Uint8List?>(null);
    final avatarExtension = useState<String?>(null);
    final initializedUserId = useRef<String?>(null);
    final hasSubmitted = useRef(false);
    // Keep the form mounted while saving, including when a save fails.
    final profileBeforeSave = useRef<UserProfile?>(null);
    final currentUid = ref.watch(authStateProvider).value?.id;
    final candidate = profileState.value ?? profileBeforeSave.value;
    final profile = candidate?.id == currentUid ? candidate : null;

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
            next.hasError
                ? '프로필을 저장하지 못했습니다. 입력은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.'
                : '프로필을 저장했습니다.',
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
      if (image == null || !context.mounted) return;
      final bytes = await image.readAsBytes();
      if (!context.mounted) return;
      avatarBytes.value = bytes;
      avatarExtension.value = image.name.split('.').last;
    }

    final dirty =
        profile != null &&
        (nameController.text.trim() != profile.displayName ||
            avatarBytes.value != null);
    Future<void> leave() async {
      if (!await exitGuard.confirm() || !context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }

    return UnsavedChangesGuard(
      dirty: dirty,
      blocked: hasSubmitted.value && profileState.isLoading,
      guard: exitGuard,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          surfaceTintColor: Colors.transparent,
          title: const Text('프로필 수정'),
          centerTitle: true,
          leading: IconButton(
            tooltip: '뒤로',
            onPressed: leave,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: _ProfileBody(
          child: AsyncValueWidget<UserProfile>(
            value: profile != null
                ? AsyncData(profile)
                : profileState.hasValue
                ? const AsyncLoading()
                : profileState,
            onRetry: () => ref.invalidate(userProfileControllerProvider),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: _ProfileAvatar(
                    displayName: data.displayName,
                    photoUrl: data.photoUrl,
                    bytes: avatarBytes.value,
                    radius: 52,
                    tooltip: '프로필 사진 변경',
                    icon: Icons.camera_alt_outlined,
                    onPressed: profileState.isLoading
                        ? null
                        : () async {
                            try {
                              await selectAvatar();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '사진을 불러오지 못했습니다. 다시 시도해 주세요.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  '이름',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  enabled: !profileState.isLoading,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: '이름을 입력해 주세요',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.controlBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.controlBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _ProfileGroup(
                  title: '로그인 계정',
                  children: [
                    _ProfileInfo(
                      icon: Icons.mail_outline_rounded,
                      label: '이메일',
                      value: data.email,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '로그인 계정 이메일은 여기서 변경할 수 없습니다.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      profileState.isLoading ||
                          !dirty ||
                          nameController.text.trim().isEmpty
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          profileBeforeSave.value = data;
                          hasSubmitted.value = true;
                          final success = await ref
                              .read(userProfileControllerProvider.notifier)
                              .updateProfile(
                                displayName: nameController.text,
                                avatarBytes: avatarBytes.value,
                                avatarExtension: avatarExtension.value,
                              );
                          if (success && context.mounted) {
                            profileBeforeSave.value = null;
                            avatarBytes.value = null;
                            avatarExtension.value = null;
                          }
                        },
                  icon: profileState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(profileState.isLoading ? '저장 중...' : '프로필 저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppStyle.fullWidth + 48),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: child,
        ),
      ),
    ),
  );
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ),
      Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 56, endIndent: 16),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

String _endLabel(UserProfile profile) {
  final lastDay = profile.pilotEndsAt
      ?.subtract(const Duration(milliseconds: 1))
      .toLocal();
  if (lastDay == null) return '등록된 이용 종료일 없음';
  return '${lastDay.year}.${lastDay.month.toString().padLeft(2, '0')}.${lastDay.day.toString().padLeft(2, '0')}까지';
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.photoUrl,
    required this.tooltip,
    required this.onPressed,
    this.bytes,
    this.radius = 44,
    this.icon = Icons.edit_outlined,
  });
  final String displayName;
  final String? photoUrl;
  final Uint8List? bytes;
  final String tooltip;
  final VoidCallback? onPressed;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final image = bytes != null
        ? MemoryImage(bytes!) as ImageProvider
        : photoUrl != null && photoUrl!.isNotEmpty
        ? NetworkImage(photoUrl!)
        : null;
    return SizedBox(
      width: radius * 2 + 12,
      height: radius * 2 + 12,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.selected,
            foregroundColor: AppColors.accent,
            foregroundImage: image,
            child: Text(
              displayName.isEmpty
                  ? '?'
                  : displayName.characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton.filledTonal(
              tooltip: tooltip,
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.surface, width: 2),
              ),
              icon: Icon(icon, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
