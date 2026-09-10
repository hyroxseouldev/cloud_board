import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';

class PairedDevicesButton extends ConsumerWidget {
  const PairedDevicesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider).value ?? const [];
    final onlineCount = devices.where((device) => device.online).length;
    return Badge(
      isLabelVisible: devices.isNotEmpty,
      label: Text('$onlineCount/${devices.length}'),
      backgroundColor: onlineCount == devices.length
          ? Colors.green
          : Colors.orange,
      child: IconButton(
        tooltip: '디스플레이 연결',
        onPressed: () => context.push('/displays'),
        icon: const Icon(Icons.connected_tv_rounded),
      ),
    );
  }
}
