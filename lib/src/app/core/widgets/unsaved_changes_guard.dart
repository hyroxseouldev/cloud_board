import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Shared by PopScope (system back) and GoRoute.onExit (links/browser history).
class ExitGuard {
  Future<bool> Function()? check;
  Future<bool> confirm() async => await check?.call() ?? true;
}

class UnsavedChangesGuard extends HookWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
    this.guard,
    this.blocked = false,
    this.onDiscard,
  });
  final bool dirty;
  final Widget child;
  final ExitGuard? guard;
  final bool blocked;
  final Future<void> Function()? onDiscard;

  @override
  Widget build(BuildContext context) {
    final allowed = useState(false);
    final pending = useRef<Future<bool>?>(null);
    Future<bool> confirm() async {
      if (blocked) return false;
      if (!dirty || allowed.value) return true;
      if (pending.value != null) return pending.value!;
      final future = showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('저장하지 않고 나갈까요?'),
          content: const Text('저장하지 않은 변경사항이 사라집니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('계속 편집'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('저장 안 하고 나가기'),
            ),
          ],
        ),
      ).then((value) => value ?? false);
      pending.value = future;
      final result = await future;
      pending.value = null;
      if (context.mounted && result) {
        await onDiscard?.call();
        if (context.mounted) allowed.value = true;
      }
      return result;
    }

    if (guard != null) guard!.check = confirm;
    useEffect(
      () => () {
        guard?.check = null;
      },
      [guard],
    );
    return PopScope(
      canPop: !blocked && (!dirty || allowed.value),
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await confirm() && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop(result);
          });
        }
      },
      child: child,
    );
  }
}
