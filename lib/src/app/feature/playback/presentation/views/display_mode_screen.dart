import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_mode_menu.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
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

    return PopScope(
      canPop: !isTv,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showBlack)
              const ColoredBox(color: Colors.black)
            else if ((isActive || showCompletion) && allowPlayback)
              WorkoutPlayerScreen(
                key: ValueKey(session.id),
                workoutId: session.workout.id,
                startModule: 0,
                sessionId: session.id,
                displayMode: true,
                onStandby: () => finishedSessionId.value = session.id,
              )
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
            if (!showBlack && !isTv)
              const Positioned(
                top: 18,
                right: 18,
                child: SafeArea(
                  child: Material(
                    color: Colors.black54,
                    shape: CircleBorder(),
                    child: DeviceModeMenu(iconColor: Colors.white),
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
    final images = brand.promotionImageUrls;
    final imageIndex = images.isEmpty
        ? 0
        : (now.millisecondsSinceEpoch ~/ 12000) % images.length;
    final next = nextSchedule(schedules, now);
    final nextDate = next == null ? null : _nextScheduleDate(next, now);
    if (currentDevice?.paired == true) {
      return StoreWelcomeBoard(
        brand: brand,
        now: now,
        connected: connected,
        nextClass: next == null || nextDate == null
            ? null
            : '${nextDate.month}/${nextDate.day} ${nextDate.hour.toString().padLeft(2, '0')}:${nextDate.minute.toString().padLeft(2, '0')} · ${next.workoutName}',
      );
    }
    final shiftIndex = now.minute % 4;
    final shift = [
      const Offset(-14, -8),
      const Offset(12, -4),
      const Offset(8, 10),
      const Offset(-10, 8),
    ][shiftIndex];
    final color = Color(brand.primaryColorValue);
    return Scaffold(
      backgroundColor: XonColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            child: images.isEmpty
                ? DecoratedBox(
                    key: const ValueKey('brand-gradient'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, XonColors.black],
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    key: ValueKey(images[imageIndex]),
                    imageUrl: images[imageIndex],
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => ColoredBox(color: color),
                  ),
          ),
          const ColoredBox(color: Colors.black38),
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            transform: Matrix4.translationValues(shift.dx, shift.dy, 0),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 1000,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (brand.logoUrl != null) ...[
                          CachedNetworkImage(
                            imageUrl: brand.logoUrl!,
                            height: 100,
                            fit: BoxFit.contain,
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 22),
                        ],
                        Text(
                          brand.storeName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 58,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 92,
                            height: 1,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          error == null
                              ? brand.standbyMessage
                              : '연결을 확인하고 있습니다',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 26,
                          ),
                        ),
                        if (next != null && nextDate != null) ...[
                          const SizedBox(height: 28),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 16,
                              ),
                              child: Text(
                                '다음 수업  ${nextDate.month}/${nextDate.day} ${nextDate.hour.toString().padLeft(2, '0')}:${nextDate.minute.toString().padLeft(2, '0')}  ·  ${next.workoutName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (currentDevice?.paired == true)
                          Text(
                            '${currentDevice!.name} · ${connected ? '온라인' : '재연결 중'}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          )
                        else
                          pairing.when(
                            loading: () => const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            error: (_, _) => OutlinedButton.icon(
                              onPressed: onRefreshPairing,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('연결 코드 다시 만들기'),
                            ),
                            data: (ticket) => _PairingCode(
                              ticket: ticket,
                              onRefresh: onRefreshPairing,
                            ),
                          ),
                        if (!isLoading && currentDevice?.paired == true)
                          TextButton.icon(
                            onPressed: onTestSound,
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('소리 테스트'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _PairingCode extends StatelessWidget {
  const _PairingCode({required this.ticket, required this.onRefresh});

  final DevicePairing ticket;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${ticket.code.substring(0, 3)} ${ticket.code.substring(3)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 12, 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '컨트롤러 연결 코드 · 10분간 유효',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  formatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: '새 연결 코드',
              autofocus: true,
              onPressed: onRefresh,
              color: Colors.white70,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
