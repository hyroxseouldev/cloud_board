import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';

class DeviceModeHomeScreen extends ConsumerWidget {
  const DeviceModeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceModeControllerProvider);
    if (state.isLoading && !state.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final mode =
        state.value ??
        ref.read(deviceModeControllerProvider.notifier).currentMode;
    return switch (mode) {
      DeviceMode.controller => const WorkoutListScreen(),
      DeviceMode.display => const DisplayModeScreen(),
    };
  }
}
