import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DisplayRefreshButton extends HookWidget {
  const DisplayRefreshButton({
    super.key,
    required this.onRefresh,
    this.autofocus = false,
  });
  final Future<void> Function() onRefresh;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    final busy = useState(false);
    final failed = useState(false);
    return FilledButton.icon(
      autofocus: autofocus,
      // Keep the TV remote focus while a refresh is running.
      onPressed: () async {
        if (busy.value) return;
        busy.value = true;
        failed.value = false;
        try {
          await onRefresh();
        } catch (_) {
          if (context.mounted) failed.value = true;
        } finally {
          if (context.mounted) busy.value = false;
        }
      },
      icon: busy.value
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(
        busy.value
            ? '새로고침 중…'
            : failed.value
            ? '연결 확인 후 다시 시도'
            : '새로고침',
      ),
    );
  }
}
