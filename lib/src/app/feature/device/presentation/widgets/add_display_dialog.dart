import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';

class AddDisplayDialog extends HookConsumerWidget {
  const AddDisplayDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = useTextEditingController();
    final name = useTextEditingController(text: '메인 디스플레이');
    final zone = useTextEditingController(text: '메인 구역');
    final action = ref.watch(deviceClaimControllerProvider);
    final submitted = useState(false);
    final codeError = useState<String?>(null);

    Future<void> connect() async {
      if (code.text.length != 6) {
        codeError.value = '6자리 코드를 입력해 주세요.';
        return;
      }
      codeError.value = null;
      submitted.value = true;
      final success = await ref
          .read(deviceClaimControllerProvider.notifier)
          .claim(code: code.text, name: name.text, zoneName: zone.text);
      if (success && context.mounted) Navigator.of(context).pop(true);
    }

    return PopScope(
      canPop: !action.isLoading,
      child: AlertDialog(
        title: const Text('디스플레이 추가'),
        content: SizedBox(
          width: 360,
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
                  decoration: InputDecoration(
                    errorText: codeError.value,
                    labelText: '디스플레이의 6자리 코드',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.pin_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('기기 이름 · 구역'),
                  children: [
                    TextField(
                      controller: name,
                      enabled: !action.isLoading,
                      decoration: const InputDecoration(labelText: '기기 이름'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: zone,
                      enabled: !action.isLoading,
                      decoration: const InputDecoration(labelText: '구역 이름'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                if (submitted.value && action.hasError) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${action.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: action.isLoading
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
