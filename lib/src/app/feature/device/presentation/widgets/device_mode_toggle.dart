import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';

class DeviceModeToggle extends ConsumerWidget {
  const DeviceModeToggle({super.key, this.enabled = true, this.onChanged});

  final bool enabled;
  final ValueChanged<DeviceMode>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceModeControllerProvider);
    final mode =
        state.value ??
        ref.read(deviceModeControllerProvider.notifier).currentMode;
    return SegmentedButton<DeviceMode>(
      segments: const [
        ButtonSegment(
          value: DeviceMode.controller,
          label: Text('Control'),
          tooltip: '워크아웃 관리 및 재생 제어',
        ),
        ButtonSegment(
          value: DeviceMode.display,
          label: Text('Display'),
          tooltip: '활성 세션 자동 재생',
        ),
      ],
      showSelectedIcon: false,
      selected: {mode},
      onSelectionChanged: !enabled || state.isLoading
          ? null
          : (selection) async {
              final selected = selection.first;
              final saved = await ref
                  .read(deviceModeControllerProvider.notifier)
                  .setMode(selected);
              if (!context.mounted) return;
              if (saved) {
                onChanged?.call(selected);
              } else {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('기기 모드를 바꾸지 못했습니다. 다시 시도해 주세요.'),
                  ),
                );
              }
            },
    );
  }
}
