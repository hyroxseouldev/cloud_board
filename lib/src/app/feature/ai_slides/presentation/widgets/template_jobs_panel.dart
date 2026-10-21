import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';

/// This persistent-results entry sits before the draft, including on re-entry.
/// No image is fetched/rendered until the owner explicitly opens a complete job.
class TemplateJobsPanel extends HookWidget {
  const TemplateJobsPanel({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onRecover,
    required this.onRetry,
    required this.onOpen,
    this.onLoadMore,
    this.showAll = false,
  });
  final TemplateJobsState state;
  final VoidCallback? onLoadMore;
  final bool showAll;
  final VoidCallback onRefresh, onRecover;
  final ValueChanged<TemplateJob> onRetry, onOpen;
  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '센터 생성 이미지',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '생성 작업 새로고침',
              onPressed: state.loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
            if (!showAll && state.jobs.length > 3)
              TextButton(
                onPressed: () => expanded.value = !expanded.value,
                child: Text(expanded.value ? '접기' : '모두 보기'),
              ),
          ],
        ),
        if (state.loading) const LinearProgressIndicator(minHeight: 2),
        if (state.error != null)
          Text(state.error!, key: const ValueKey('template-jobs-error')),
        if (state.unresolved)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('이전 요청의 접수 여부를 확인해 주세요. 새 AI 요청을 보내지 않습니다.'),
              TextButton(
                key: const ValueKey('template-recover'),
                onPressed: state.submitting ? null : onRecover,
                child: const Text('접수 확인'),
              ),
            ],
          ),
        if (!state.loading && state.error == null && state.jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('접수한 작업은 여기에 남아요. 완성 후 열어서 저장하거나 수업에 추가하세요.'),
          ),
        for (final job in state.jobs.take(
          showAll || expanded.value ? state.jobs.length : 3,
        ))
          Card(
            key: ValueKey('template-job-${job.requestId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${job.designName} · ${switch (job.status) {
                      'pending' => '접수됨',
                      'processing' => '생성 중',
                      'complete' => '완성됨',
                      _ => '생성 실패',
                    }}',
                  ),
                  if (job.inProgress) const Text('화면을 나가도 생성은 계속됩니다.'),
                  if (job.message != null) Text(job.message!),
                  ExpansionTile(
                    title: const Text('입력 내용 보기'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(job.title),
                      if (job.subtitle.isNotEmpty) SelectableText(job.subtitle),
                      SelectableText(
                        job.rawWod,
                        key: ValueKey('template-source-${job.requestId}'),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      if (job.complete)
                        TextButton(
                          key: ValueKey('template-open-${job.requestId}'),
                          onPressed: state.opening ? null : () => onOpen(job),
                          child: Text(state.opening ? '불러오는 중…' : '열기'),
                        ),
                      if (job.status == 'failed' && job.retryable)
                        TextButton(
                          onPressed: state.submitting || state.unresolved
                              ? null
                              : () => onRetry(job),
                          child: const Text('다시 생성 (AI 1회)'),
                        ),
                      if (job.status == 'failed' && !job.retryable)
                        const Text('자동 재시도하지 않아요. 상태를 확인해 주세요.'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (onLoadMore != null && state.nextCursor != null)
          TextButton(
            onPressed: state.loadingMore ? null : onLoadMore,
            child: Text(state.loadingMore ? '불러오는 중…' : '이전 생성 작업 더 보기'),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
