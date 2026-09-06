import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
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
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _PairedDevicesDialog(),
        ),
        icon: const Icon(Icons.connected_tv_rounded),
      ),
    );
  }
}

class _PairedDevicesDialog extends HookConsumerWidget {
  const _PairedDevicesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = useTextEditingController();
    final name = useTextEditingController(text: '메인 디스플레이');
    final zone = useTextEditingController(text: '메인 구역');
    final devices = ref.watch(displayDevicesProvider);
    final action = ref.watch(deviceClaimControllerProvider);

    Future<void> connect() async {
      final success = await ref
          .read(deviceClaimControllerProvider.notifier)
          .claim(code: code.text, name: name.text, zoneName: zone.text);
      if (success) code.clear();
    }

    return AlertDialog(
      title: const Text('디스플레이 연결'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: code,
                enabled: !action.isLoading,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: '디스플레이의 6자리 코드',
                  hintText: '123456',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: name,
                      enabled: !action.isLoading,
                      decoration: const InputDecoration(labelText: '기기 이름'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: zone,
                      enabled: !action.isLoading,
                      decoration: const InputDecoration(labelText: '구역 이름'),
                    ),
                  ),
                ],
              ),
              if (action.hasError) ...[
                const SizedBox(height: 10),
                Text(
                  '${action.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: action.isLoading ? null : connect,
                icon: action.isLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: const Text('연결하기'),
              ),
              const Divider(height: 34),
              Text('등록된 디스플레이', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              devices.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Text('기기 목록을 불러오지 못했습니다. $error'),
                data: (items) => items.isEmpty
                    ? const Text('아직 등록된 디스플레이가 없습니다.')
                    : Column(
                        children: items
                            .map(
                              (device) => _DeviceTile(
                                device: device,
                                onRemove: () => ref
                                    .read(
                                      deviceClaimControllerProvider.notifier,
                                    )
                                    .unpair(device.id),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onRemove});

  final DisplayDevice device;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      Icons.circle,
      size: 12,
      color: device.online ? Colors.green : Colors.grey,
    ),
    title: Text(device.name),
    subtitle: Text(
      '${device.zoneName} · ${device.online ? '온라인' : '오프라인'}'
      '${device.acknowledgedRevision > 0 ? ' · 명령 확인 #${device.acknowledgedRevision}' : ''}',
    ),
    trailing: IconButton(
      tooltip: '연결 해제',
      onPressed: onRemove,
      icon: const Icon(Icons.link_off_rounded),
    ),
  );
}
