import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';

import 'package:cloud_board/src/app/feature/update_news/presentation/controllers/update_news_controller.dart';

class UpdateNewsTile extends ConsumerWidget {
  const UpdateNewsTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(updateNewsControllerProvider).value?.hasUnread ?? false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Row(
        children: [
          const Flexible(child: Text('업데이트 소식')),
          if (unread) ...[
            const SizedBox(width: 8),
            Semantics(
              label: '새 소식 있음',
              child: const DecoratedBox(
                key: ValueKey('update-news-unread'),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 7),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/profile/updates'),
    );
  }
}
