import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';

class RenameDisplayDialog extends HookConsumerWidget {
  const RenameDisplayDialog({super.key, required this.device});
  final DisplayDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useTextEditingController(text: device.name);
    final zone = useTextEditingController(text: device.zoneName);
    final form = useMemoized(() => GlobalKey<FormState>());
    final submitted = useState(false);
    final action = ref.watch(deviceClaimControllerProvider);
    String? validate(String? value) =>
        value == null || value.trim().isEmpty ? '이름을 입력해 주세요.' : null;
    Future<void> save() async {
      if (!form.currentState!.validate()) return;
      submitted.value = true;
      final success = await ref
          .read(deviceClaimControllerProvider.notifier)
          .rename(deviceId: device.id, name: name.text, zoneName: zone.text);
      if (success && context.mounted) Navigator.of(context).pop();
    }

    return PopScope(
      canPop: !action.isLoading,
      child: AppAlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('디스플레이 이름 수정')),
            IconButton(
              tooltip: '닫기',
              onPressed: action.isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                enabled: !action.isLoading,
                maxLength: 60,
                validator: validate,
                decoration: const InputDecoration(labelText: '기기 이름'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: zone,
                enabled: !action.isLoading,
                maxLength: 60,
                validator: validate,
                decoration: const InputDecoration(labelText: '구역 이름'),
              ),
              if (submitted.value && action.hasError)
                const Text('이름을 수정하지 못했습니다. 연결 상태를 확인하고 다시 시도해 주세요.'),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: action.isLoading ? null : save,
              child: Text(action.isLoading ? '수정 중…' : '수정'),
            ),
          ),
        ],
      ),
    );
  }
}
