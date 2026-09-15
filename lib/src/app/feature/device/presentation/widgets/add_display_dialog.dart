import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_pairing_error_message.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_qr_scanner_screen.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
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
    final canScan =
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) &&
        ref.watch(androidTvProvider).value == false;
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
      child: AppAlertDialog(
        title: const Text('디스플레이 추가'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('연결할 디스플레이의 코드를 입력해 주세요.'),
                const SizedBox(height: 16),
                _PairingCodeInput(controller: code, enabled: !action.isLoading),
                if (codeError.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      codeError.value!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (canScan) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: action.isLoading
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            final scanned = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DisplayQrScannerScreen(),
                                  ),
                                );
                            if (scanned != null && context.mounted) {
                              code.text = scanned;
                              codeError.value = null;
                            }
                          },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('QR 코드 스캔'),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
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
                    devicePairingErrorMessage(action.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
    );
  }
}

class _PairingCodeInput extends HookWidget {
  const _PairingCodeInput({required this.controller, required this.enabled});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final focus = useFocusNode();
    useListenable(focus);
    useListenable(controller);
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.selected,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              focus.hasFocus &&
                                  i == controller.text.length.clamp(0, 5)
                              ? AppColors.accent
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          i < controller.text.length ? controller.text[i] : '',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(color: Colors.transparent),
              showCursor: false,
              enableInteractiveSelection: true,
              decoration: const InputDecoration(
                labelText: '디스플레이의 6자리 코드',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                labelStyle: TextStyle(color: Colors.transparent),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
