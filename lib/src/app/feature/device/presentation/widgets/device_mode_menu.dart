import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/device_mode.dart';
import '../controllers/device_mode_controller.dart';

class DeviceModeMenu extends ConsumerWidget {
  const DeviceModeMenu({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceModeControllerProvider);
    final mode =
        state.value ??
        ref.read(deviceModeControllerProvider.notifier).currentMode;
    return PopupMenuButton<DeviceMode>(
      tooltip: '기기 모드',
      enabled: !state.isLoading,
      initialValue: mode,
      onSelected: (value) =>
          ref.read(deviceModeControllerProvider.notifier).setMode(value),
      icon: state.isLoading
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconColor,
              ),
            )
          : Icon(Icons.devices_rounded, color: iconColor),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: DeviceMode.controller,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tune_rounded),
            title: Text('컨트롤러 모드'),
            subtitle: Text('워크아웃 관리 및 재생 제어'),
          ),
        ),
        PopupMenuItem(
          value: DeviceMode.display,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tv_rounded),
            title: Text('디스플레이 모드'),
            subtitle: Text('활성 세션 자동 재생'),
          ),
        ),
      ],
    );
  }
}
