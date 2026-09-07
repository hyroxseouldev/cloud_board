import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_readiness.dart';

class WorkoutPreflightSelection {
  WorkoutPreflightSelection({required Iterable<String> targetDeviceIds})
    : targetDeviceIds = List.unmodifiable(targetDeviceIds);

  final List<String> targetDeviceIds;
}

Future<WorkoutPreflightSelection?> showWorkoutPreflight(
  BuildContext context,
  Workout workout,
) => showDialog<WorkoutPreflightSelection>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WorkoutPreflightDialog(workout: workout),
);

class WorkoutPreflightDialog extends HookConsumerWidget {
  const WorkoutPreflightDialog({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider).value ?? const [];
    final onlineDevices = devices.where((item) => item.online).toList();
    final selectedDeviceIds = useState<Set<String>>(
      onlineDevices.map((device) => device.id).toSet(),
    );
    final initializedDeviceSelection = useRef(onlineDevices.isNotEmpty);
    final imageCheck = useState<AsyncValue<int>>(const AsyncLoading());
    final countdown = useState<int?>(null);
    final readiness = evaluateWorkoutReadiness(workout);

    useEffect(() {
      var cancelled = false;

      Future<void> precacheAfterBuild() async {
        if (cancelled || !context.mounted) return;
        try {
          final count = await _precacheImages(context, workout);
          if (!cancelled && context.mounted) {
            imageCheck.value = AsyncData(count);
          }
        } catch (error, stack) {
          if (!cancelled && context.mounted) {
            imageCheck.value = AsyncError(error, stack);
          }
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(precacheAfterBuild());
      });

      return () => cancelled = true;
    }, [workout.id, workout.updatedAt]);

    final onlineDeviceIds = onlineDevices.map((device) => device.id).toSet();
    final onlineDeviceSignature = onlineDeviceIds.toList()..sort();
    useEffect(() {
      final retained = selectedDeviceIds.value.intersection(onlineDeviceIds);
      final next = !initializedDeviceSelection.value && retained.isEmpty
          ? onlineDeviceIds
          : retained;
      if (onlineDeviceIds.isNotEmpty) initializedDeviceSelection.value = true;
      if (!_sameIds(next, selectedDeviceIds.value)) {
        Future.microtask(() {
          if (context.mounted) selectedDeviceIds.value = next;
        });
      }
      return null;
    }, [onlineDeviceSignature.join('|')]);

    final canStart =
        readiness.isReady &&
        imageCheck.value.hasValue &&
        (onlineDevices.isEmpty || selectedDeviceIds.value.isNotEmpty) &&
        countdown.value == null;

    Future<void> start() async {
      for (var value = 3; value > 0; value--) {
        countdown.value = value;
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!context.mounted) return;
      }
      if (context.mounted) {
        Navigator.of(context).pop(
          WorkoutPreflightSelection(targetDeviceIds: selectedDeviceIds.value),
        );
      }
    }

    return AlertDialog(
      title: Text(
        countdown.value == null ? '수업 시작 전 점검' : '${countdown.value}',
      ),
      content: SizedBox(
        width: 520,
        child: countdown.value != null
            ? const Text(
                '디스플레이를 확인해 주세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CheckTile(
                      ok: readiness.isReady,
                      title: '${workout.modules.length}개 슬라이드',
                      subtitle: readiness.isReady
                          ? '총 수업 시간 ${durationLabel(workoutDuration(workout))}'
                          : readiness.issues.join('\n'),
                    ),
                    imageCheck.value.when(
                      loading: () => const _CheckTile(
                        ok: null,
                        title: '이미지 준비 중',
                        subtitle: '수업 이미지를 미리 불러오고 있습니다.',
                      ),
                      error: (error, _) => _CheckTile(
                        ok: false,
                        title: '이미지 준비 실패',
                        subtitle: '$error',
                      ),
                      data: (count) => _CheckTile(
                        ok: true,
                        title: '이미지 준비 완료',
                        subtitle: '$count개 이미지를 확인했습니다.',
                      ),
                    ),
                    _CheckTile(
                      ok: onlineDevices.isNotEmpty,
                      title: onlineDevices.isEmpty
                          ? '온라인 디스플레이 없음'
                          : '${onlineDevices.length}대 온라인',
                      subtitle: onlineDevices.isEmpty
                          ? '이 기기에서만 재생할 수 있습니다.'
                          : '${selectedDeviceIds.value.length}대를 선택했습니다.',
                    ),
                    if (onlineDevices.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '재생 디스플레이',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              selectedDeviceIds.value =
                                  selectedDeviceIds.value.length ==
                                      onlineDevices.length
                                  ? <String>{}
                                  : onlineDeviceIds;
                            },
                            child: Text(
                              selectedDeviceIds.value.length ==
                                      onlineDevices.length
                                  ? '전체 해제'
                                  : '전체 선택',
                            ),
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 190),
                        child: ListView(
                          shrinkWrap: true,
                          children: onlineDevices
                              .map(
                                (device) => CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: selectedDeviceIds.value.contains(
                                    device.id,
                                  ),
                                  title: Text(device.name),
                                  subtitle: Text(device.zoneName),
                                  onChanged: (checked) {
                                    final next = Set<String>.from(
                                      selectedDeviceIds.value,
                                    );
                                    if (checked == true) {
                                      next.add(device.id);
                                    } else {
                                      next.remove(device.id);
                                    }
                                    selectedDeviceIds.value = next;
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(beepPlayerProvider).play(),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('소리 테스트'),
                    ),
                  ],
                ),
              ),
      ),
      actions: countdown.value == null
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              FilledButton.icon(
                onPressed: canStart ? start : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('3초 후 시작'),
              ),
            ]
          : null,
    );
  }
}

bool _sameIds(Set<String> first, Set<String> second) =>
    first.length == second.length && first.containsAll(second);

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.ok,
    required this.title,
    required this.subtitle,
  });

  final bool? ok;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ok == null
        ? const CircularProgressIndicator()
        : Icon(
            ok! ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok! ? Colors.green : Colors.orange,
          ),
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

Future<int> _precacheImages(BuildContext context, Workout workout) async {
  var count = 0;
  for (final module in workout.modules) {
    final source = module.imageSource;
    if (source.isEmpty) continue;
    final ImageProvider provider;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      provider = CachedNetworkImageProvider(source);
    } else {
      provider = MemoryImage(WorkoutImageSource.decode(source).bytes);
    }
    await precacheImage(provider, context);
    count++;
  }
  return count;
}
