import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_recovery_dialog.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_content_transition.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
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
  const DisplaySettingsScreen({super.key, this.asMainTab = false});
  final bool asMainTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    final nowMs =
        ref.watch(displayHealthNowProvider).value ??
        DateTime.now().millisecondsSinceEpoch;
    final pendingRemoval = useState<String?>(null);
    final changingOutput = useState(false);
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
    ref.listen(deviceClaimControllerProvider, (previous, next) {
      if (next.hasError && next.error != previous?.error) {
        final error = next.error!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FirebaseException && error.code == 'resource-exhausted'
                  ? '동시 송출 한도에 도달했습니다. 송출 중인 TV를 먼저 끄거나 구독 관리에서 한도를 확인해 주세요.'
                  : diagnosticMessage(error),
            ),
            action: SnackBarAction(
              label: '문제 문의하기',
              onPressed: () => openSupportForError(
                context,
                ref.read(errorReporterProvider),
                next.error!,
                next.stackTrace,
                'pairing.action',
              ),
            ),
          ),
        );
      }
    });
    final modeState = ref.watch(deviceModeControllerProvider);
    final busy =
        action.isLoading || modeState.isLoading || changingOutput.value;
    final stackedMode = MediaQuery.textScalerOf(context).scale(14) > 18;
    final modeControl = DeviceModeToggle(
      enabled: !busy,
      direction: stackedMode ? Axis.vertical : Axis.horizontal,
      onChanged: (selected) {
        if (selected == DeviceMode.display) context.go('/');
      },
    );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        toolbarHeight: 64,
        actions: stackedMode ? null : [modeControl, const SizedBox(width: 18)],
        automaticallyImplyLeading: false,
        leading: asMainTab
            ? null
            : BackButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              if (stackedMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: modeControl,
                  ),
                ),
              Text('디스플레이 설정', style: AppStyle.of(context).mainText),
              const SizedBox(height: 8),
              Text(
                devices.isLoading
                    ? '등록된 TV와 연결 상태를 확인하고 있습니다.'
                    : devices.hasError
                    ? 'TV 상태를 확인하지 못했습니다. 아래에서 다시 불러와 주세요.'
                    : devices.value?.isEmpty == true
                    ? 'TV 앱을 열고 QR 또는 6자리 코드로 첫 화면을 연결하세요.'
                    : '등록 ${devices.value?.length ?? 0}대 · 온라인 ${devices.value?.where((device) => device.recentlySeen(nowMs)).length ?? 0}대',
                style: const TextStyle(color: AppColors.secondaryText),
              ),
              if (devices.hasValue && devices.value!.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '최근 서버 응답을 기준으로 표시합니다. 수업 준비와 연결 권한은 TV 메뉴의 연결 복구에서 확인하세요.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/displays/connect'),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('처음 연결하나요? TV 연결 안내'),
                ),
              ),
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
                      nowMs: nowMs,
                      busy: busy || pendingRemoval.value != null,
                      removing: pendingRemoval.value == device.id,
                      onToggle: (enabled) async {
                        if (changingOutput.value) return;
                        changingOutput.value = true;
                        try {
                          var replaceDeviceIds = const <String>[];
                          final activeOthers = items
                              .where(
                                (d) =>
                                    d.id != device.id &&
                                    d.paired &&
                                    d.displayState == 'auto',
                              )
                              .toList();
                          if (enabled && activeOthers.isNotEmpty) {
                            try {
                              final profile = await ref.read(
                                userProfileControllerProvider.future,
                              );
                              if (!context.mounted) return;
                              if (!profile.unlimitedDisplays &&
                                  profile.hasPlanDisplayPolicy &&
                                  activeOthers.length >= profile.displayLimit) {
                                if (profile.displayLimit <= 0) {
                                  throw StateError(
                                    'Display allowance is not confirmed',
                                  );
                                }
                                final selected = await showDialog<List<String>>(
                                  context: context,
                                  builder: (_) => _DisplaySwitchDialog(
                                    target: device.name,
                                    active: activeOthers,
                                    limit: profile.displayLimit,
                                  ),
                                );
                                if (selected == null || !context.mounted) {
                                  return;
                                }
                                replaceDeviceIds = selected;
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
                                replaceDeviceIds: replaceDeviceIds,
                              );
                          if (!success &&
                              context.mounted &&
                              !ref
                                  .read(deviceClaimControllerProvider)
                                  .hasError) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('화면 표시를 변경하지 못했습니다. 다시 시도해 주세요.'),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) changingOutput.value = false;
                        }
                      },
                      onRecover: () =>
                          showDisplayRecovery(context, ref, device),
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
    required this.nowMs,
    required this.busy,
    required this.removing,
    required this.onRemove,
    required this.onRename,
    required this.onPreferences,
    required this.onToggle,
    required this.onRecover,
  });
  final DisplayDevice device;
  final int nowMs;
  final bool busy;
  final bool removing;
  final VoidCallback onRemove;
  final VoidCallback onRename;
  final VoidCallback onPreferences;
  final VoidCallback onRecover;
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
                  child: Switch(
                    value: device.displayState == 'auto',
                    onChanged: busy ? null : onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.of(context).subText3,
                  ),
                  const SizedBox(height: 4),
                  AppContentTransition(
                    transitionKey:
                        '${device.recentlySeen(nowMs)}:${device.appBuild}:${device.lastSeenAtMs}',
                    child: Text(
                      '${device.zoneName} · ${device.recentlySeen(nowMs) ? '온라인' : '오프라인'}\n'
                      '${device.displayState == 'auto' ? '송출 켜짐' : '송출 꺼짐'} · ${device.recentlySeen(nowMs) ? '최근 응답 수신' : '연결 확인 필요'}'
                      '${device.recentlySeen(nowMs) ? '' : '\nTV 앱과 인터넷 연결을 확인해 주세요.'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
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
                onSelected: (value) => value == 'recover'
                    ? onRecover()
                    : value == 'rename'
                    ? onRename()
                    : value == 'preferences'
                    ? onPreferences()
                    : onRemove(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'recover', child: Text('연결 복구')),
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

/// Explicit replacement only: a server-confirmed allowance never implies that
/// another coach's screen can be silently removed from the class.
class _DisplaySwitchDialog extends HookWidget {
  const _DisplaySwitchDialog({
    required this.target,
    required this.active,
    required this.limit,
  });
  final String target;
  final List<DisplayDevice> active;
  final int limit;
  @override
  Widget build(BuildContext context) {
    final selected = useState<Set<String>>({});
    final requiredCount = active.length - limit + 1;
    return AppAlertDialog(
      title: const Text('송출 화면을 변경할까요?'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '동시에 $limit대까지 송출할 수 있습니다. $target에서 이어서 표시하려면 중지할 TV를 $requiredCount대 이상 선택하세요. 등록은 유지됩니다.',
              ),
              const SizedBox(height: 12),
              for (final device in active)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name),
                  subtitle: Text(device.zoneName),
                  value: selected.value.contains(device.id),
                  onChanged: (checked) => selected.value = checked == true
                      ? {...selected.value, device.id}
                      : ({...selected.value}..remove(device.id)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: selected.value.length < requiredCount
              ? null
              : () => Navigator.pop(context, selected.value.toList()),
          child: const Text('선택한 TV 대신 송출'),
        ),
      ],
    );
  }
}
