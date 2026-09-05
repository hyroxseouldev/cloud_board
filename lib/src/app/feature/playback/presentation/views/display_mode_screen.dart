import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/services/beep_player.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../device/presentation/widgets/device_mode_menu.dart';
import '../../../workouts/presentation/views/workout_player_screen.dart';
import '../../domain/entities/playback_session.dart';
import '../controllers/playback_session_controller.dart';

class DisplayModeScreen extends ConsumerWidget {
  const DisplayModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePlaybackSessionProvider);

    final session = active.value;
    final isActive =
        session != null &&
        session.status != PlaybackStatus.completed &&
        session.workout.modules.isNotEmpty;

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
            onTestSound: () async {
              try {
                await ref.read(beepPlayerProvider).play();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('디스플레이 소리가 활성화되었습니다.')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('소리를 재생하지 못했습니다: $error')),
                  );
                }
              }
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
    required this.onTestSound,
  });

  final bool isLoading;
  final Object? error;
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
              height: 430,
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
                  const SizedBox(height: 32),
                  if (isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    FilledButton.icon(
                      onPressed: onTestSound,
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('소리 테스트 및 활성화'),
                    ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: Color(0xFF43D17A), size: 10),
                      SizedBox(width: 8),
                      Text(
                        '실시간 세션 대기 중',
                        style: TextStyle(color: Colors.white54),
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
