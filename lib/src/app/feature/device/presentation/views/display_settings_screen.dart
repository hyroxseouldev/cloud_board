import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/add_display_dialog.dart';

class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    final action = ref.watch(deviceClaimControllerProvider);
    final modeState = ref.watch(deviceModeControllerProvider);
    final mode =
        modeState.value ??
        ref.read(deviceModeControllerProvider.notifier).currentMode;
    final busy = action.isLoading || modeState.isLoading;
    final modeControl = SegmentedButton<DeviceMode>(
      segments: const [
        ButtonSegment(value: DeviceMode.controller, label: Text('Control')),
        ButtonSegment(value: DeviceMode.display, label: Text('Display')),
      ],
      showSelectedIcon: false,
      selected: {mode},
      onSelectionChanged: busy
          ? null
          : (selection) async {
              final selected = selection.first;
              final success = await ref
                  .read(deviceModeControllerProvider.notifier)
                  .setMode(selected);
              if (success &&
                  selected == DeviceMode.display &&
                  context.mounted) {
                context.go('/');
              }
            },
    );
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    '디스플레이 설정',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  );
                  if (constraints.maxWidth < 480) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: modeControl,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 16),
                      modeControl,
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '등록된 디스플레이',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const AddDisplayDialog(),
                          ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('추가'),
                        SizedBox(width: 6),
                        Icon(Icons.add_rounded),
                      ],
                    ),
                  ),
                ],
              ),
              if (modeState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '기기 모드를 바꾸지 못했습니다. 다시 시도해 주세요.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              devices.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Column(
                  children: [
                    const Text('등록된 디스플레이를 불러오지 못했습니다.'),
                    TextButton(
                      onPressed: () => ref.invalidate(displayDevicesProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          '아직 등록된 디스플레이가 없습니다.\n위의 추가 버튼으로 연결해 주세요.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: [
                          for (final device in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DisplayTile(
                                device: device,
                                busy: busy,
                                onRemove: () async {
                                  await ref
                                      .read(
                                        deviceClaimControllerProvider.notifier,
                                      )
                                      .unpair(device.id);
                                  if (context.mounted &&
                                      ref
                                          .read(deviceClaimControllerProvider)
                                          .hasError) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '연결을 해제하지 못했습니다. 다시 시도해 주세요.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisplayTile extends StatelessWidget {
  const _DisplayTile({
    required this.device,
    required this.busy,
    required this.onRemove,
  });
  final DisplayDevice device;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF5F5F9),
    borderRadius: BorderRadius.circular(4),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      trailing: PopupMenuButton<String>(
        tooltip: '디스플레이 메뉴',
        enabled: !busy,
        onSelected: (_) => onRemove(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'remove', child: Text('연결 해제')),
        ],
      ),
    ),
  );
}
