import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_readiness.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';

class WorkoutPreflightSelection {
  WorkoutPreflightSelection({
    required Iterable<String> targetDeviceIds,
    this.preparation,
    this.localOnly = false,
  }) : targetDeviceIds = List.unmodifiable(targetDeviceIds);

  final List<String> targetDeviceIds;
  final DisplayPreparationProof? preparation;
  final bool localOnly;
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
    final onlineDevices = devices
        .where((item) => item.paired && item.displayState == 'auto')
        .toList();
    final selectedDeviceIds = useState<Set<String>>(
      onlineDevices
          .where((device) => device.online)
          .map((device) => device.id)
          .toSet(),
    );
    final initializedDeviceSelection = useRef(onlineDevices.isNotEmpty);
    final imageCheck = useState<AsyncValue<int>>(const AsyncLoading());
    final readiness = evaluateWorkoutReadiness(workout);
    useEffect(() {
      var cancelled = false;
      final reporter = ref.read(errorReporterProvider);

      Future<void> precacheAfterBuild() async {
        if (cancelled || !context.mounted) return;
        try {
          final count = await precacheWorkoutImages(
            context,
            workoutImageWindow(workout, count: 2, includeCountdown: true),
            isCancelled: () => cancelled,
          );
          if (!cancelled && context.mounted) {
            imageCheck.value = AsyncData(count);
          }
        } catch (error, stack) {
          reporter.capture(error, stack, action: 'workout.preflight.images');
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
          ? onlineDevices
                .where((device) => device.online)
                .map((device) => device.id)
                .toSet()
          : retained;
      if (onlineDeviceIds.isNotEmpty) initializedDeviceSelection.value = true;
      if (!_sameIds(next, selectedDeviceIds.value)) {
        Future.microtask(() {
          if (context.mounted) selectedDeviceIds.value = next;
        });
      }
      return null;
    }, [onlineDeviceSignature.join('|')]);

    final selected = onlineDevices
        .where((d) => selectedDeviceIds.value.contains(d.id))
        .toList();
    final modern = selected.where((d) => d.preparationProtocol >= 1).toList();
    final legacy = selected.where((d) => d.preparationProtocol < 1).toList();
    final legacyConfirmed = useState(false);
    final retry = useState(0);
    final offset = modern.isEmpty
        ? 0
        : ref.watch(serverTimeOffsetProvider).value ?? 0;
    final clock = useState(DateTime.now().millisecondsSinceEpoch);
    final signature = (selectedDeviceIds.value.toList()..sort()).join('|');
    final fingerprint = preparationFingerprint(
      workout,
      selectedDeviceIds.value,
    );
    final preparation = modern.isEmpty
        ? const DisplayPreparationState()
        : ref.watch(displayPreparationControllerProvider);
    useEffect(() {
      Future.microtask(() {
        if (context.mounted) legacyConfirmed.value = false;
      });
      if (modern.isNotEmpty) {
        Future.microtask(() {
          if (context.mounted) {
            unawaited(
              ref
                  .read(displayPreparationControllerProvider.notifier)
                  .prepare(workout, selectedDeviceIds.value.toList()),
            );
          }
        });
      }
      return null;
    }, [workout, signature, retry.value]);
    useEffect(() {
      if (modern.isEmpty) return null;
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => clock.value = DateTime.now().millisecondsSinceEpoch,
      );
      return timer.cancel;
    }, [modern.isNotEmpty]);
    final requiredProtocol = requiredTimingProtocol(workout);
    final matchingRequest = preparation.request?.manifestHash == fingerprint
        ? preparation.request
        : null;
    DisplayPreparationStatus statusOf(device) => displayPreparationStatus(
      device,
      requiredProtocol,
      matchingRequest,
      preparation.receipts[device.id],
      preparationServerNow(offset, localNowMs: clock.value),
    );
    final allPrepared = selected.every(
      (d) => switch (statusOf(d)) {
        DisplayPreparationStatus.ready => true,
        DisplayPreparationStatus.legacy => legacyConfirmed.value,
        _ => false,
      },
    );
    final canStart =
        readiness.isReady && imageCheck.value.hasValue && allPrepared;

    Future<void> start() async {
      if (context.mounted) {
        Navigator.of(context).pop(
          WorkoutPreflightSelection(
            targetDeviceIds: selectedDeviceIds.value,
            localOnly: selectedDeviceIds.value.isEmpty && devices.isNotEmpty,
            preparation: selected.isEmpty
                ? null
                : DisplayPreparationProof(
                    manifestHash: fingerprint,
                    sessionId: matchingRequest?.sessionId,
                    revision: matchingRequest?.revision,
                    legacyDeviceIds: legacyConfirmed.value
                        ? legacy.map((d) => d.id).toList()
                        : const [],
                  ),
          ),
        );
      }
    }

    return AppAlertDialog(
      scrollable: false,
      title: const Text('수업 준비'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CheckTile(
                ok: readiness.isReady,
                title: '${workout.modules.length}개 슬라이드',
                subtitle: readiness.isReady
                    ? '총 수업 시간 ${workoutDurationText(workout)}'
                    : readiness.issues.join('\n'),
              ),
              imageCheck.value.when(
                loading: () => const _CheckTile(
                  ok: null,
                  title: '시작 이미지 준비 중',
                  subtitle: '시작 화면과 다음 슬라이드를 준비하고 있습니다.',
                ),
                error: (error, _) => _CheckTile(
                  ok: false,
                  title: '이미지 준비 실패',
                  subtitle: workoutErrorMessage(
                    error,
                    fallback: '이미지를 준비하지 못했습니다. 인터넷 연결과 슬라이드 이미지를 확인한 뒤 수업 준비를 다시 열어 주세요.',
                  ),
                ),
                data: (count) => _CheckTile(
                  ok: true,
                  title: '이미지 준비 완료',
                  subtitle: '$count개 이미지를 확인했습니다.',
                ),
              ),
              _CheckTile(
                ok: onlineDevices.any((d) => d.online),
                title: !onlineDevices.any((d) => d.online)
                    ? '온라인 디스플레이 없음'
                    : '${onlineDevices.where((d) => d.online).length}대 온라인',
                subtitle: selectedDeviceIds.value.isEmpty
                    ? '이 기기에서만 재생합니다. TV에는 수업을 보내지 않아요.'
                    : '${selectedDeviceIds.value.length}대를 선택했습니다.',
              ),
              if (modern.isNotEmpty) ...[
                _CheckTile(
                  ok:
                      matchingRequest != null &&
                      modern.every(
                        (d) => statusOf(d) == DisplayPreparationStatus.ready,
                      ),
                  title:
                      'TV ${selected.length}대 중 ${modern.where((d) => statusOf(d) == DisplayPreparationStatus.ready).length}대 준비 완료',
                  subtitle:
                      '${preparation.error ?? '선택한 수업의 이미지와 소리를 각 TV에서 확인해요.'}\n'
                      '준비되지 않은 TV는 체크를 해제하면 제외하고 수업을 시작할 수 있어요.',
                ),
                TextButton(
                  onPressed: preparation.loading ? null : () => retry.value++,
                  child: const Text('TV 준비 다시 확인'),
                ),
              ],
              if (legacy.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: legacyConfirmed.value,
                  onChanged: (value) => legacyConfirmed.value = value ?? false,
                  title: const Text('구형 TV 화면을 직접 확인했어요'),
                  subtitle: const Text(
                    '이 TV는 자료 준비를 자동 확인할 수 없어요. 업데이트하거나 화면을 직접 확인한 뒤 기존 방식으로 시작해요.',
                  ),
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
                        selectedDeviceIds.value.length == onlineDevices.length
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
                            value: selectedDeviceIds.value.contains(device.id),
                            title: Text(device.name),
                            subtitle: Text(
                              '${device.zoneName} · ${device.installedVersion}\n${_preparationLabel(statusOf(device))}',
                            ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: canStart ? start : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('수업 시작'),
        ),
      ],
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

String _preparationLabel(DisplayPreparationStatus status) => switch (status) {
  DisplayPreparationStatus.offline => '최근 응답 없음 · 연결 확인 또는 제외',
  DisplayPreparationStatus.updateRequired => '이 수업은 TV 업데이트가 필요해요',
  DisplayPreparationStatus.legacy => '구형 TV · 자료 준비 자동 확인 불가',
  DisplayPreparationStatus.waiting => '이 수업의 이미지·소리 준비 중',
  DisplayPreparationStatus.failed => '자료 준비 실패 · 재시도 또는 제외',
  DisplayPreparationStatus.ready => '이 수업의 이미지·소리 준비 완료',
  DisplayPreparationStatus.expired => '준비 확인 만료 · 다시 확인해 주세요',
};
