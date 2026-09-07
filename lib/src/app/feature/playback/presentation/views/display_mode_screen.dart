import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_mode_menu.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

class DisplayModeScreen extends HookConsumerWidget {
  const DisplayModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePlaybackSessionProvider);
    final pairing = ref.watch(devicePairingControllerProvider);
    final connected = ref.watch(playbackConnectionProvider).value ?? false;
    final deviceId = ref.watch(deviceIdProvider).value;
    final devices = ref.watch(displayDevicesProvider).value ?? const [];
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
        session.workout.modules.isNotEmpty;

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

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isActive)
          WorkoutPlayerScreen(
            workoutId: session.workout.id,
            startModule: 0,
            sessionId: session.id,
            displayMode: true,
          )
        else
          _DisplayStandby(
            isLoading: active.isLoading,
            error: active.error,
            pairing: pairing,
            currentDevice: currentDevice,
            onRefreshPairing: () =>
                ref.read(devicePairingControllerProvider.notifier).refresh(),
            connected: connected,
            onTestSound: () async {
              try {
                await ref.read(beepPlayerProvider).play();
              } catch (_) {}
            },
          ),
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
  });

  final bool isLoading;
  final Object? error;
  final AsyncValue<DevicePairing> pairing;
  final DisplayDevice? currentDevice;
  final Future<void> Function() onRefreshPairing;
  final bool connected;
  final Future<void> Function() onTestSound;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: XonColors.black,
    body: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 680,
              height: 560,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tv_rounded, color: Colors.white, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'DISPLAY READY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error == null
                        ? '컨트롤러에서 워크아웃을 재생하면\n이 화면에서 자동으로 시작됩니다.'
                        : '재생 세션 연결에 실패했습니다.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (currentDevice?.paired == true)
                    _PairedDeviceStatus(device: currentDevice!)
                  else
                    pairing.when(
                      loading: () => const SizedBox(
                        height: 86,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
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
                  const SizedBox(height: 24),
                  if (isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    FilledButton.icon(
                      onPressed: onTestSound,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('소리 테스트 및 활성화'),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        color: connected
                            ? const Color(0xFF43D17A)
                            : Colors.orange,
                        size: 10,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        connected ? '실시간 세션 대기 중' : '오프라인 · 재연결 중',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PairedDeviceStatus extends StatelessWidget {
  const _PairedDeviceStatus({required this.device});

  final DisplayDevice device;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF43D17A).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF43D17A).withValues(alpha: .5)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            device.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${device.zoneName}에 연결됨',
            style: const TextStyle(color: Color(0xFF43D17A)),
          ),
        ],
      ),
    ),
  );
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
