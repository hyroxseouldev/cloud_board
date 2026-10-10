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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.secondaryText),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(path),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('더보기'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Text(
            user?.displayName.trim().isNotEmpty == true
                ? '${user!.displayName}님'
                : '내 계정',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          destination(
            '프로필 및 설정',
            '계정 정보와 센터 정보',
            Icons.account_circle_outlined,
            '/profile',
          ),
          const Divider(height: 1),
          if (user != null) ...[
            destination(
              '매장 관리',
              '워크아웃 기본값 · 대기 화면 · 예약 재생',
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
          destination(
            '업데이트 소식',
            'CloudBoard의 새로운 기능',
            Icons.campaign_outlined,
            '/profile/updates',
          ),
        ],
      ),
    );
  }
}
