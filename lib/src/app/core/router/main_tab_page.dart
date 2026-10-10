import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Keep tab UI while browsing, but never carry its filters into another account.
class MainTabPage extends ConsumerWidget {
  const MainTabPage({super.key, required this.child, this.home = false});

  final Widget child;
  final bool home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authStateProvider.select((s) => s.value?.id));
    return PopScope(
      canPop: home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !home) context.go('/');
      },
      child: KeyedSubtree(key: ValueKey(account), child: child),
    );
  }
}
