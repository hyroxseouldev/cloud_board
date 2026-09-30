import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';

import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/controllers/update_news_controller.dart';

class UpdateNewsScreen extends ConsumerWidget {
  const UpdateNewsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _NewsPage(
    title: '업데이트 소식',
    fallback: '/profile',
    child: AsyncValueWidget<UpdateNewsState>(
      value: ref.watch(updateNewsControllerProvider),
      onRetry: () => ref.invalidate(updateNewsControllerProvider),
      data: (state) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(updateNewsControllerProvider);
          try {
            await ref.read(updateNewsControllerProvider.future);
          } catch (_) {
            // The provider renders the error and offers retry.
          }
        },
        child: ListView(
          key: const PageStorageKey('update-news-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              '달라진 점을 한눈에.',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '지금 사용하는 버전의 새로운 기능과 개선 사항을 확인하세요.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            if (state.notes.isEmpty)
              const _NewsEmpty(message: '아직 등록된 업데이트 소식이 없어요.'),
            for (final note in state.notes) ...[
              _NewsCard(note: note, unread: !state.readIds.contains(note.id)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
  );
}

class UpdateNewsDetailScreen extends HookConsumerWidget {
  const UpdateNewsDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateNewsControllerProvider);
    final note = state.value?.notes.where((note) => note.id == id).firstOrNull;
    Future<void> markRead() async {
      try {
        await ref.read(updateNewsControllerProvider.notifier).markRead(id);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('읽은 상태를 저장하지 못했어요.'),
            action: SnackBarAction(label: '다시 시도', onPressed: markRead),
          ),
        );
      }
    }

    useEffect(() {
      if (note != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            markRead();
          }
        });
      }
      return null;
    }, [note?.id]);
    return _NewsPage(
      title: '업데이트 소식',
      fallback: '/profile/updates',
      child: AsyncValueWidget<UpdateNewsState>(
        value: state,
        onRetry: () => ref.invalidate(updateNewsControllerProvider),
        data: (_) => note == null
            ? const _NewsEmpty(message: '이 버전에서 확인할 수 없는 소식이에요.')
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NewsMeta(note: note),
                    const SizedBox(height: 16),
                    Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      note.summary,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: AppColors.muted,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(),
                    ),
                    for (var i = 0; i < note.items.length; i++) ...[
                      Semantics(
                        header: true,
                        child: Text(
                          note.items[i].title,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        note.items[i].body,
                        style: const TextStyle(fontSize: 16, height: 1.65),
                      ),
                      if (i + 1 < note.items.length) const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _NewsPage extends StatelessWidget {
  const _NewsPage({
    required this.title,
    required this.fallback,
    required this.child,
  });
  final String title, fallback;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: '뒤로',
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(fallback),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox.expand(child: child),
        ),
      ),
    ),
  );
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.note, required this.unread});
  final UpdateNews note;
  final bool unread;
  @override
  Widget build(BuildContext context) => Semantics(
    label: unread ? '읽지 않은 소식' : null,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/profile/updates/${note.id}'),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NewsMeta(note: note, unread: unread),
              const SizedBox(height: 14),
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('자세히 보기', style: TextStyle(color: AppColors.accent)),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NewsMeta extends StatelessWidget {
  const _NewsMeta({required this.note, this.unread = false});
  final UpdateNews note;
  final bool unread;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        note.date.replaceAll('-', '.'),
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      Text(
        '·  v${note.version}',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      if (unread)
        const Text(
          'NEW',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _NewsEmpty extends StatelessWidget {
  const _NewsEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 36,
            color: AppColors.accent,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
