import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';

class DeviceModeHomeScreen extends HookConsumerWidget {
  const DeviceModeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceModeControllerProvider);
    final mode =
        state.value ??
        ref.read(deviceModeControllerProvider.notifier).currentMode;
    useEffect(() {
      if (mode != DeviceMode.controller) return null;
      void checkSchedules() {
        unawaited(ref.read(scheduleRunnerControllerProvider.notifier).runDue());
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => checkSchedules());
      final timer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => checkSchedules(),
      );
      return timer.cancel;
    }, [mode]);
    if (state.isLoading && !state.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activeSession = ref.watch(activePlaybackSessionProvider).value;
    final shouldRestoreController =
        mode == DeviceMode.controller &&
        activeSession != null &&
        activeSession.status != PlaybackStatus.completed &&
        activeSession.workout.modules.isNotEmpty;
    if (shouldRestoreController) {
      return WorkoutPlayerScreen(
        workoutId: activeSession.workout.id,
        startModule: 0,
        sessionId: activeSession.id,
      );
    }
    return switch (mode) {
      DeviceMode.controller => const WorkoutListScreen(),
      DeviceMode.display => const DisplayModeScreen(),
    };
  }
}
