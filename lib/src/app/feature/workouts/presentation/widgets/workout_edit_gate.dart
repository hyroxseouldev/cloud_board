import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

/// Surrounds the editor navigator (including nested timer/settings sheets).
/// Keep the navigator mounted so a remote start never discards an open draft.
class WorkoutEditGate extends HookConsumerWidget {
  const WorkoutEditGate({
    super.key,
    required this.workoutId,
    required this.child,
  });
  final String? workoutId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activePlaybackSessionProvider);
    final reason = workoutId == null
        ? null
        : workoutEditBlockReason(session, workoutId!);
    useEffect(() {
      if (reason != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            FocusManager.instance.primaryFocus?.unfocus();
            // Dialogs using the root navigator sit above the editor shell.
            // Dismiss those transient editors too, without popping a page.
            Navigator.of(
              context,
              rootNavigator: true,
            ).popUntil((route) => route is! PopupRoute);
          }
        });
      }
      return null;
    }, [reason]);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: reason != null, child: child),
        if (reason != null)
          Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: '홈으로',
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('편집 잠금'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 40),
                    const SizedBox(height: 16),
                    Text(reason, textAlign: TextAlign.center),
                    if (reason == workoutPlayingEditMessage) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '일시정지 중에도 편집은 잠깁니다. 수업을 종료하면 다시 편집할 수 있습니다.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '이 화면에서 편집하던 내용은 유지됩니다.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (session.hasError)
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(activePlaybackSessionProvider),
                        child: const Text('다시 확인'),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
