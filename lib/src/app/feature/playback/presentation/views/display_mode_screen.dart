import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_refresh_button.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_pairing_card.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_mode_toggle.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';

class DisplayModeScreen extends HookConsumerWidget {
  const DisplayModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(androidTvProvider).value ?? false;
    final active = ref.watch(activePlaybackSessionProvider);
    final pairing = ref.watch(devicePairingControllerProvider);
    ref.listen(accountOwnerIdProvider, (previous, next) {
      if (previous == null || previous.value == next.value || next.isLoading) {
        return;
      }
      unawaited(ref.read(devicePairingControllerProvider.notifier).refresh());
    });
    final connected = ref.watch(playbackConnectionProvider).value ?? false;
    final deviceId = ref.watch(deviceIdProvider).value;
    final devices = ref.watch(displayDevicesProvider).value ?? const [];
    final brand =
        ref.watch(brandTemplateProvider).value ?? BrandTemplate.initial();
    final schedules =
        ref.watch(workoutSchedulesProvider).value ?? const <WorkoutSchedule>[];
    final now = useState(DateTime.now());
    final finishedSessionId = useState<String?>(null);
    final serverOffset = ref.watch(serverTimeOffsetProvider).value ?? 0;
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);
    useEffect(() {
      if (!isTv) return null;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      unawaited(WakelockPlus.enable());
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () {
        unawaited(WakelockPlus.disable());
        unawaited(SystemChrome.setPreferredOrientations(const []));
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      };
    }, [isTv]);
    final currentDevice = devices
        .where((item) => item.id == deviceId)
        .firstOrNull;

    final session = active.value;
    final targetsThisDevice =
        session == null ||
        (session.targetDeviceIds.isEmpty
            ? currentDevice == null || session.zoneId == currentDevice.zoneId
            : deviceId != null && session.targetDeviceIds.contains(deviceId));
    final isActive =
        session != null &&
        session.status != PlaybackStatus.completed &&
        targetsThisDevice &&
        finishedSessionId.value != session.id &&
        session.workout.modules.isNotEmpty;
    final showCompletion =
        session != null &&
        session.status == PlaybackStatus.completed &&
        targetsThisDevice &&
        finishedSessionId.value != session.id &&
        now.value.millisecondsSinceEpoch +
                serverOffset -
                session.anchorServerMs <
            5000;
    final remoteState = currentDevice?.displayState ?? 'auto';
    final showBlack =
        remoteState == RemoteDisplayState.black.name ||
        (!isActive && isBlackScreenTime(brand, now.value));
    final allowPlayback = remoteState == RemoteDisplayState.auto.name;
    useEffect(
      () {
        var cancelled = false;
        if (isActive && session.briefing && allowPlayback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (cancelled || !context.mounted) return;
            unawaited(
              precacheWorkoutImages(
                context,
                session.workout.modules.map((module) => module.imageSource),
                isCancelled: () => cancelled,
              ).catchError((Object error) {
                debugPrint('Display image preparation failed: $error');
                return 0;
              }),
            );
          });
        }
        return () => cancelled = true;
      },
      [
        session?.id,
        session?.workout,
        session?.briefing,
        isActive,
        allowPlayback,
      ],
    );

    useEffect(() {
      if (!isActive || deviceId == null) return null;
      unawaited(
        ref
            .read(devicePairingActionsProvider)
            .acknowledge(
              deviceId: deviceId,
              sessionId: session.id,
              revision: session.revision,
            )
            .catchError((_) {}),
      );
      return null;
    }, [deviceId, session?.id, session?.revision, isActive]);

    // The standby clock continues to enforce scheduled black-screen periods,
    // but must not rebuild a playing slide each second.
    final player = useMemoized(
      () => session == null
          ? const SizedBox.shrink()
          : WorkoutPlayerScreen(
              key: ValueKey(session.id),
              workoutId: session.workout.id,
              startModule: 0,
              sessionId: session.id,
              displayMode: true,
              displayPreferences:
                  currentDevice?.preferences ?? const DisplayPreferences(),
              onStandby: () => finishedSessionId.value = session.id,
            ),
      [session?.id, currentDevice?.preferences],
    );
    return PopScope(
      canPop: !isTv,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showBlack)
              const ColoredBox(color: Colors.black)
            else if ((isActive || showCompletion) &&
                allowPlayback &&
                session.briefing != true)
              player
            else
              _DisplayStandby(
                isLoading: active.isLoading,
                error: active.error,
                pairing: pairing,
                currentDevice: currentDevice,
                onRefreshPairing: () => ref
                    .read(devicePairingControllerProvider.notifier)
                    .refresh(),
                connected: connected,
                brand: brand,
                schedules: schedules,
                now: now.value,
                onTestSound: () async {
                  try {
                    await ref.read(beepPlayerProvider).play();
                  } catch (_) {}
                },
              ),
            if (!showBlack &&
                (!isActive || session.briefing) &&
                currentDevice?.paired == true)
              Positioned(
                top: isTv ? 24 : 100,
                right: 24,
                child: SafeArea(
                  child: DisplayRefreshButton(
                    autofocus: isTv,
                    onRefresh: () async {
                      ref.invalidate(activePlaybackSessionProvider);
                      ref.invalidate(displayDevicesProvider);
                      ref.invalidate(brandTemplateProvider);
                      ref.invalidate(workoutSchedulesProvider);
                      ref.invalidate(playbackConnectionProvider);
                      await Future.wait([
                        ref.read(activePlaybackSessionProvider.future),
                        ref.read(displayDevicesProvider.future),
                        ref.read(brandTemplateProvider.future),
                        ref.read(workoutSchedulesProvider.future),
                      ]).timeout(const Duration(seconds: 10));
                      final online = await ref
                          .read(playbackConnectionProvider.future)
                          .timeout(const Duration(seconds: 5));
                      if (!online) throw StateError('네트워크 연결을 확인해 주세요.');
                    },
                  ),
                ),
              ),
            if (!showBlack && !isTv)
              const Positioned(
                top: 18,
                right: 18,
                child: SafeArea(
                  child: Material(
                    color: AppColors.surface,
                    elevation: 2,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppStyle.controlRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: DeviceModeToggle(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisplayStandby extends StatelessWidget {
  const _DisplayStandby({
    required this.isLoading,
    required this.error,
    required this.pairing,
    required this.currentDevice,
    required this.onRefreshPairing,
    required this.connected,
    required this.onTestSound,
    required this.brand,
    required this.schedules,
    required this.now,
  });

  final bool isLoading;
  final Object? error;
  final AsyncValue<DevicePairing> pairing;
  final DisplayDevice? currentDevice;
  final Future<void> Function() onRefreshPairing;
  final bool connected;
  final Future<void> Function() onTestSound;
  final BrandTemplate brand;
  final List<WorkoutSchedule> schedules;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = nextSchedule(schedules, now);
    final nextDate = next == null ? null : _nextScheduleDate(next, now);
    if (currentDevice?.paired == true) {
      return StoreWelcomeBoard(
        brand: brand,
        displayPreferences:
            currentDevice?.preferences ?? const DisplayPreferences(),
        now: now,
        connected: connected,
        nextClass: next == null || nextDate == null
            ? null
            : '${nextDate.month}/${nextDate.day} ${nextDate.hour.toString().padLeft(2, '0')}:${nextDate.minute.toString().padLeft(2, '0')} · ${next.workoutName}',
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pairing.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('연결 코드를 불러오지 못했습니다. 네트워크를 확인해 주세요.'),
                    TextButton.icon(
                      onPressed: onRefreshPairing,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('연결 코드 다시 만들기'),
                    ),
                  ],
                ),
                data: (ticket) => DisplayPairingCard(
                  ticket: ticket,
                  now: now,
                  onRefresh: onRefreshPairing,
                ),
              ),
              if (!connected || error != null)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    '네트워크 연결을 확인하고 있습니다.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              if (!isLoading)
                TextButton.icon(
                  onPressed: onTestSound,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('소리 테스트'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _nextScheduleDate(WorkoutSchedule schedule, DateTime now) {
  for (var offset = 0; offset < 8; offset++) {
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: offset));
    if (!schedule.weekdays.contains(day.weekday)) continue;
    final date = scheduledDateTime(schedule, day);
    if (date.isAfter(now)) return date;
  }
  return scheduledDateTime(schedule, now.add(const Duration(days: 7)));
}
