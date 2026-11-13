import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_image_budget.dart';

class WorkoutImageBudgetNotice extends StatelessWidget {
  const WorkoutImageBudgetNotice({
    super.key,
    required this.usage,
    required this.hasCountdown,
    required this.onRetry,
    this.failed = false,
  });
  final WorkoutImageUsage? usage;
  final bool hasCountdown, failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final value = usage;
    final error = failed || (value?.failed ?? false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '이미지 용량 · ${value?.totalLabel ?? (error ? '확인하지 못함' : '확인 중…')}',
              key: const ValueKey('workout-image-usage'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: value?.exceedsLimit == true
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '워크아웃당 이미지 총 100 MB까지 저장할 수 있어요. 같은 이미지는 한 번만 합산하며, 카운트다운 이미지도 포함해요. (1 MB = 1,000,000바이트)',
            style: TextStyle(fontSize: 12),
          ),
          if (hasCountdown)
            Text(
              '카운트다운 이미지 · ${value == null
                  ? '확인 중…'
                  : value.countdownBytes == null
                  ? '용량 확인 불가'
                  : imageMegabytes(value.countdownBytes!)}',
              style: const TextStyle(fontSize: 12),
            ),
          if (value?.exceedsLimit == true)
            Text(
              WorkoutImageBudgetExceeded(value!.knownBytes).message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (error || (value?.unknownCount ?? 0) > 0) ...[
            Text(
              error
                  ? '일부 이미지 용량을 확인하지 못했어요. 연결을 확인하고 다시 시도해 주세요. 저장할 때 서버에서 다시 확인해요.'
                  : '용량 미확인 이미지 ${value!.unknownCount}개는 합계에 포함되지 않았어요. 기존 외부 이미지는 다시 선택하면 용량을 확인할 수 있어요.',
              style: const TextStyle(fontSize: 12),
            ),
            TextButton(onPressed: onRetry, child: const Text('용량 다시 확인')),
          ],
        ],
      ),
    );
  }
}
