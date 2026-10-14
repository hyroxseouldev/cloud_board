import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    Widget destination(
      String title,
      String subtitle,
      IconData icon,
      String path,
    ) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      leading: Icon(icon, color: AppColors.accent),
      title: Text(
        title,
        style: const TextStyle(
          letterSpacing: -0.16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.secondaryText),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(path),
    );

    final name = user?.displayName.trim();
    Widget group(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppColors.accent),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('더보기'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 350 ? 16 : 20,
              16,
              20,
              32,
            ),
            children: [
              ListTile(
                key: const ValueKey('more-profile-summary'),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.selected,
                  foregroundColor: AppColors.accent,
                  foregroundImage: user?.photoUrl?.isNotEmpty == true
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: Text(
                    name?.isNotEmpty == true ? name!.characters.first : '나',
                  ),
                ),
                title: Text(
                  name?.isNotEmpty == true ? name! : '내 계정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: const Text('프로필 및 설정'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/profile'),
              ),
              const Divider(height: 24),
              group('수업과 센터'),
              if (user != null) ...[
                destination(
                  '매장 관리',
                  '기본값 · 대기 화면 · 예약 재생',
                  Icons.storefront_outlined,
                  '/operations',
                ),
                const Divider(height: 1),
              ],
              destination(
                '구독 관리',
                '이용 중인 플랜과 결제 정보',
                Icons.credit_card_outlined,
                '/subscription',
              ),
              const Divider(height: 1),
              group('도움말'),
              destination(
                '문의하기',
                '문제 상황과 스크린샷 보내기',
                Icons.help_outline_rounded,
                '/support',
              ),
              const Divider(height: 1),
              group('시작과 소식'),
              destination(
                '첫 수업 준비',
                '수업 만들기부터 TV 연결까지',
                Icons.checklist_rounded,
                '/first-class',
              ),
              const Divider(height: 1),
              destination(
                '예시 수업 둘러보기',
                '예시를 체험하고 내 수업으로 시작하기',
                Icons.auto_awesome_mosaic_outlined,
                '/explore',
              ),
              const Divider(height: 1),
              destination(
                '업데이트 소식',
                '${AppBrand.name}의 새로운 기능',
                Icons.campaign_outlined,
                '/profile/updates',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
