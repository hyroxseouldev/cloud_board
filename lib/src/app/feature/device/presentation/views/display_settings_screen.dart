import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/animated_display_list.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_preferences_dialog.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/rename_display_dialog.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/add_display_dialog.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';

class DisplaySettingsScreen extends HookConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    final pendingRemoval = useState<String?>(null);
    final removed = useState<Set<String>>({});
    ref.listen(displayDevicesProvider, (previous, next) {
      if (!next.hasValue || next.isLoading) return;
      // Keep successful removals hidden until the stream confirms their absence.
      final retained = removed.value
          .where((id) => next.value!.any((d) => d.id == id))
          .toSet();
      if (retained.length != removed.value.length) removed.value = retained;
    });
    final action = ref.watch(deviceClaimControllerProvider);
    final modeState = ref.watch(deviceModeControllerProvider);
    final busy = action.isLoading || modeState.isLoading;
    final modeControl = DeviceModeToggle(
      enabled: !busy,
      onChanged: (selected) {
        if (selected == DeviceMode.display) context.go('/');
      },
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 64,
        actions: [modeControl, const SizedBox(width: 18)],
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
              Text('디스플레이 설정', style: AppStyle.of(context).mainText),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '등록된 디스플레이',
                      style: AppStyle.of(context).subText2,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.only(left: 12),
                    ),
                    onPressed: busy
                        ? null
                        : () => showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            barrierColor: AppColors.accent.withValues(
                              alpha: 0.22,
                            ),
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
                data: (items) => AnimatedDisplayList(
                  devices: items
                      .where((d) => !removed.value.contains(d.id))
                      .toList(),
                  pendingRemoval: pendingRemoval.value,
                  itemBuilder: (device) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DisplayTile(
                      device: device,
                      busy: busy || pendingRemoval.value != null,
                      removing: pendingRemoval.value == device.id,
                      onToggle: (enabled) async {
                        if (enabled &&
                            items.any(
                              (d) =>
                                  d.id != device.id && d.displayState == 'auto',
                            )) {
                          try {
                            final profile = await ref.read(
                              userProfileControllerProvider.future,
                            );
                            if (!context.mounted) return;
                            if (profile.subscriptionPlan == 'plus') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AppAlertDialog(
                                  title: const Text('송출 화면을 변경할까요?'),
                                  content: Text(
                                    '플러스는 동시에 1대에 송출할 수 있습니다. 기존 화면의 송출을 끄고 ${device.name}에서 이어서 표시합니다.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('취소'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('변경'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) return;
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '플랜 정보를 확인하지 못했습니다. 다시 시도해 주세요.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                        }
                        final success = await ref
                            .read(deviceClaimControllerProvider.notifier)
                            .setDisplayState(
                              deviceId: device.id,
                              displayState: enabled ? 'auto' : 'standby',
                            );
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('화면 표시를 변경하지 못했습니다. 다시 시도해 주세요.'),
                            ),
                          );
                        }
                      },
                      onPreferences: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            DisplayPreferencesDialog(device: device),
                      ),
                      onRename: () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: AppColors.accent.withValues(alpha: 0.22),
                        builder: (_) => RenameDisplayDialog(device: device),
                      ),
                      onRemove: () async {
                        if (pendingRemoval.value != null) return;
                        pendingRemoval.value = device.id;
                        final success = await ref
                            .read(deviceClaimControllerProvider.notifier)
                            .unpair(device.id);
                        if (!context.mounted) return;
                        if (success &&
                            (ref
                                    .read(displayDevicesProvider)
                                    .value
                                    ?.any((d) => d.id == device.id) ??
                                false)) {
                          removed.value = {...removed.value, device.id};
                        }
                        pendingRemoval.value = null;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '${device.name} 디스플레이 연결을 해제했습니다.'
                                  : '연결을 해제하지 못했습니다. 다시 시도해 주세요.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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
    required this.removing,
    required this.onRemove,
    required this.onRename,
    required this.onPreferences,
    required this.onToggle,
  });
  final DisplayDevice device;
  final bool busy;
  final bool removing;
  final VoidCallback onRemove;
  final VoidCallback onRename;
  final VoidCallback onPreferences;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppStyle.controlRadius),
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
                    child: Switch(
                      value: device.displayState == 'auto',
                      onChanged: busy ? null : onToggle,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
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
                    style: AppStyle.of(context).subText3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.zoneName} · ${device.online ? '온라인' : '오프라인'}'
                    '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (removing)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: '디스플레이 메뉴',
                enabled: !busy,
                icon: const Icon(Icons.more_vert, color: AppColors.muted),
                onSelected: (value) => value == 'rename'
                    ? onRename()
                    : value == 'preferences'
                    ? onPreferences()
                    : onRemove(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('이름 수정')),
                  PopupMenuItem(value: 'preferences', child: Text('화면 맞춤')),
                  PopupMenuItem(value: 'remove', child: Text('연결 해제')),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
