import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';

final imageUsageProvider = FutureProvider.autoDispose<ImageUsage>(
  (ref) => ref.watch(imageUsageSourceProvider).usage(),
);

class ImageUsagePanel extends ConsumerWidget {
  const ImageUsagePanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(imageUsageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이미지 사용량', style: Theme.of(context).textTheme.titleMedium),
        const Text('Free · 보관 100MB · 하루 업로드 30MB · 수업당 100MB'),
        const Text('Free · 전송 하루 50MB · 월 500MB'),
        const Text('Premium · 보관 1GB · 하루 업로드 500MB · 수업당 100MB'),
        const Text('Premium · 전송 하루 1GB · 월 20GB'),
        const Text('MB·GB는 1,000 기준 · 일·월 경계는 한국 시간'),
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Row(
            children: [
              const Expanded(child: Text('사용량 확인 실패')),
              TextButton(
                onPressed: () => ref.invalidate(imageUsageProvider),
                child: const Text('다시 확인'),
              ),
            ],
          ),
          data: (usage) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '기준 시각 · ${DateTime.fromMillisecondsSinceEpoch(usage.measuredAtMs, isUtc: true).add(const Duration(hours: 9)).toIso8601String().substring(0, 19).replaceAll('T', ' ')} KST',
              ),
              Text(
                '${usage.storage.complete ? '보관' : '확인된 보관'} · 사용 ${decimalImageBytes(usage.storage.usedBytes)} · 예약 ${decimalImageBytes(usage.storage.reservedBytes)} · 미확정 ${decimalImageBytes(usage.storage.unknownBytes)}',
              ),
              if (!usage.storage.complete || usage.attribution != 'gateway')
                const Text('기존 경로의 측정되지 않은 사용량이 있어요. 전체 사용량으로 표시하지 않습니다.'),
              for (final entry in [
                ('오늘 업로드', usage.uploadDay),
                ('오늘 전송', usage.downloadDay),
                ('이번 달 전송', usage.downloadMonth),
              ])
                if (entry.$2 case final period?) ...[
                  Text(
                    '${entry.$1} · 사용 ${decimalImageBytes(period.usedBytes)} / ${decimalImageBytes(period.limitBytes)}',
                  ),
                  Text(
                    '예약 ${decimalImageBytes(period.reservedBytes)} · 미확정 ${decimalImageBytes(period.unknownBytes)} · 남은 ${decimalImageBytes(period.remainingBytes)}',
                  ),
                  if (period.grantedBytes > 0)
                    Text('추가 제공 ${decimalImageBytes(period.grantedBytes)}'),
                  if (period.protectedOverageBytes > 0)
                    Text(
                      '진행 수업 보호 전송 ${decimalImageBytes(period.protectedOverageBytes)}',
                    ),
                ],
              if (usage.nextEligibleAtMs case final next?)
                Text(
                  '다음 이용 가능 시각 · ${DateTime.fromMillisecondsSinceEpoch(next).toLocal()}',
                ),
              const Text('진행 중인 동일 수업은 한도나 준비 시간 만료로 중단되지 않아요.'),
            ],
          ),
        ),
      ],
    );
  }
}
