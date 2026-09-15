import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_viewport.dart';

class DisplayPreferencesDialog extends HookConsumerWidget {
  const DisplayPreferencesDialog({super.key, required this.device});
  final DisplayDevice device;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(device.preferences);
    final busy = useState(false);
    final error = useState(false);
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      ValueChanged<double> update,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ${(value * 100).round()}%'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 100).round(),
          label: '${(value * 100).round()}%',
          onChanged: update,
        ),
      ],
    );
    return PopScope(
      canPop: !busy.value,
      child: AppAlertDialog(
        title: Text('${device.name} 화면 맞춤'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: AbsorbPointer(
              absorbing: busy.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('배경의 크기와 위치를 조정합니다. 글자와 타이머는 안전 여백 안에 유지됩니다.'),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: DisplayViewport(
                      preferences: draft.value,
                      child: DisplayTestPattern(preferences: draft.value),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('화면 맞춤 사용'),
                    value: draft.value.enabled,
                    onChanged: (v) =>
                        draft.value = draft.value.copyWith(enabled: v),
                  ),
                  SwitchListTile(
                    title: const Text('꽉 채우기'),
                    subtitle: const Text('끄면 이미지 전체 보이기'),
                    value: draft.value.cover,
                    onChanged: (v) => draft.value = draft.value.copyWith(
                      enabled: true,
                      cover: v,
                    ),
                  ),
                  slider(
                    '배경 확대율',
                    draft.value.zoom,
                    .8,
                    1.3,
                    (v) => draft.value = draft.value.copyWith(
                      enabled: true,
                      zoom: v,
                    ),
                  ),
                  slider(
                    '가로 위치',
                    draft.value.offsetX,
                    -.1,
                    .1,
                    (v) => draft.value = draft.value.copyWith(
                      enabled: true,
                      offsetX: v,
                    ),
                  ),
                  slider(
                    '세로 위치',
                    draft.value.offsetY,
                    -.1,
                    .1,
                    (v) => draft.value = draft.value.copyWith(
                      enabled: true,
                      offsetY: v,
                    ),
                  ),
                  slider(
                    '안전 여백',
                    draft.value.safeInset,
                    0,
                    .15,
                    (v) => draft.value = draft.value.copyWith(
                      enabled: true,
                      safeInset: v,
                    ),
                  ),
                  TextButton(
                    onPressed: () => draft.value = const DisplayPreferences(),
                    child: const Text('기본값 복원'),
                  ),
                  if (error.value)
                    const Text('저장하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy.value ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: busy.value
                ? null
                : () async {
                    busy.value = true;
                    final success = await ref
                        .read(deviceClaimControllerProvider.notifier)
                        .savePreferences(device.id, draft.value);
                    if (!context.mounted) return;
                    busy.value = false;
                    error.value = !success;
                    if (success) Navigator.pop(context);
                  },
            child: Text(busy.value ? '저장 중…' : '저장'),
          ),
        ],
      ),
    );
  }
}

class DisplayTestPattern extends StatelessWidget {
  const DisplayTestPattern({super.key, required this.preferences});
  final DisplayPreferences preferences;
  DisplayPreferences get effective =>
      preferences.enabled ? preferences : const DisplayPreferences();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        ClipRect(
          child: Transform.translate(
            offset: Offset(
              c.maxWidth * effective.offsetX,
              c.maxHeight * effective.offsetY,
            ),
            child: Transform.scale(
              scale: effective.zoom,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: c.maxWidth * effective.safeInset + 6,
            vertical: c.maxHeight * effective.safeInset + 6,
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  '안전 영역',
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
