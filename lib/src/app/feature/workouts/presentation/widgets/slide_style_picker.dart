import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Style selection and deletion share one live list; applying a style is handled
/// by the editor, and persistence stays in its controller.
class SlideStylePicker extends HookWidget {
  const SlideStylePicker({
    super.key,
    required this.styles,
    required this.slides,
    required this.onDelete,
  });

  final List<WorkoutModule> styles;
  final List<WorkoutModule> slides;
  final Future<void> Function(WorkoutModule) onDelete;

  @override
  Widget build(BuildContext context) {
    final deleting = useState<String?>(null);
    final error = useState<String?>(null);
    final colors = Theme.of(context).colorScheme;

    Future<void> remove(WorkoutModule style) async {
      if (deleting.value != null) return;
      deleting.value = style.id;
      error.value = null;
      try {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AppAlertDialog(
            title: const Text('스타일을 삭제할까요?'),
            content: Text(
              '‘${style.name}’ 스타일이 내 스타일에서 삭제됩니다.\n이미 적용한 슬라이드는 바뀌지 않아요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        await onDelete(style);
      } catch (_) {
        if (context.mounted) {
          error.value = '스타일을 삭제하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
        }
      } finally {
        if (context.mounted) deleting.value = null;
      }
    }

    Widget section({
      required String title,
      required String description,
      required String emptyMessage,
      required List<WorkoutModule> items,
      bool canDelete = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(emptyMessage),
          ),
        for (final style in items) ...[
          ListTile(
            key: ValueKey('style-${canDelete ? 'saved' : 'slide'}-${style.id}'),
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 32,
            horizontalTitleGap: 12,
            minVerticalPadding: 12,
            minTileHeight: 64,
            title: Text(style.name),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(slideColor(style, rest: false, text: false)),
                border: Border.all(color: colors.outlineVariant),
              ),
            ),
            onTap: deleting.value == null
                ? () => Navigator.pop(context, style)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_right),
                if (canDelete)
                  IconButton(
                    tooltip: '${style.name} 스타일 삭제',
                    onPressed: deleting.value == null
                        ? () => remove(style)
                        : null,
                    icon: Icon(
                      deleting.value == style.id
                          ? Icons.hourglass_top_rounded
                          : Icons.delete_outline,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: ListView(
          key: const ValueKey('slide-style-list'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '스타일 불러오기',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('색상·배치·표시 옵션을 가져옵니다.\n시간, 제목, 이미지는 유지됩니다.'),
            const SizedBox(height: 24),
            if (error.value != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  error.value!,
                  style: TextStyle(color: colors.error),
                ),
              ),
              const SizedBox(height: 12),
            ],
            section(
              title: '내 스타일',
              description: '계정에 저장한 스타일을 불러옵니다.',
              emptyMessage: '저장한 스타일이 없습니다. 타이머 설정에서 스타일을 저장해 보세요.',
              items: styles,
              canDelete: true,
            ),
            const SizedBox(height: 24),
            section(
              title: '이 워크아웃의 슬라이드',
              description: '다른 슬라이드의 스타일을 가져옵니다.',
              emptyMessage: '스타일을 가져올 다른 슬라이드가 없습니다.',
              items: slides,
            ),
          ],
        ),
      ),
    );
  }
}
