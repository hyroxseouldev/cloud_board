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
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF161616),
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF78749D),
                      padding: const EdgeInsets.only(left: 12),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                        SizedBox(width: 8),
                        Icon(Icons.add, size: 22),
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
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DisplayTile(
                                device: device,
                                busy: busy,
                                onToggle: (enabled) async {
                                  final success = await ref
                                      .read(
                                        deviceClaimControllerProvider.notifier,
                                      )
                                      .setDisplayState(
                                        deviceId: device.id,
                                        displayState: enabled
                                            ? 'auto'
                                            : 'black',
                                      );
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '화면 표시를 변경하지 못했습니다. 다시 시도해 주세요.',
                                        ),
                                      ),
                                    );
                                  }
                                },
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
    required this.onToggle,
  });
  final DisplayDevice device;
  final bool busy;
  final VoidCallback onRemove;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF5F4F8),
    borderRadius: BorderRadius.circular(4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Tooltip(
                message: '화면 표시',
                child: Semantics(
                  label: '${device.name} 화면 표시',
                  child: Transform.scale(
                    scale: 0.85,
                    child: Theme(
                      data: ThemeData(
                        useMaterial3: false,
                        colorScheme: Theme.of(context).colorScheme,
                      ),
                      child: Switch(
                        value: device.displayState != 'black',
                        onChanged: busy ? null : onToggle,
                        activeTrackColor: const Color(0xFF78749D),
                        activeThumbColor: const Color(0xFFDCD9E9),
                        inactiveTrackColor: const Color(0xFFD8D5E2),
                        inactiveThumbColor: const Color(0xFFEFEDF4),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF777484),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.zoneName} · ${device.online ? '온라인' : '오프라인'}'
                    '${device.acknowledgedRevision > 0 ? ' · 명령 확인 #${device.acknowledgedRevision}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF817E8E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '디스플레이 메뉴',
              enabled: !busy,
              icon: const Icon(
                Icons.more_vert,
                size: 16,
                color: Color(0xFFB9B5CE),
              ),
              onSelected: (_) => onRemove(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('연결 해제')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
