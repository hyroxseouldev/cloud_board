import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/controllers/billing_controller.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/account_deletion_controller.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/presentation/controllers/app_update_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

/// Never obscure an active class (including paused/offline recovery), editing or
/// payment. The Navigator subtree stays mounted when a required update appears.
class AppUpdateGate extends HookConsumerWidget {
  const AppUpdateGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateControllerProvider).value;
    useOnAppLifecycleStateChange((previous, next) {
      if (next == AppLifecycleState.resumed) {
        ref.invalidate(appUpdateControllerProvider);
      }
    });
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(hours: 1),
        (_) => ref.invalidate(appUpdateControllerProvider),
      );
      return timer.cancel;
    }, const []);
    final router = ref.watch(appRouterProvider);
    useListenable(router.routeInformationProvider);
    final route = router.routeInformationProvider.value.uri.path;
    final tv = ref.watch(androidTvProvider).value;
    final auth = ref.watch(authStateProvider);
    final session = update == null || auth.value == null
        ? null
        : ref.watch(activePlaybackSessionProvider);
    final deferred =
        tv != false ||
        auth.isLoading ||
        auth.hasError ||
        ref.watch(authControllerProvider).isLoading ||
        ref.watch(billingPurchaseControllerProvider).busy ||
        ref.watch(accountDeletionControllerProvider).isLoading ||
        !['/', '/profile', '/login'].contains(route) ||
        (session != null &&
            (session.isLoading ||
                session.hasError ||
                (session.value != null &&
                    session.value!.status != PlaybackStatus.completed)));
    return UpdatePresentation(
      release: update?.release,
      kind: deferred ? UpdateKind.none : update?.kind ?? UpdateKind.none,
      onLater: () => ref.read(appUpdateControllerProvider.notifier).later(),
      onRetry: () => ref.read(appUpdateControllerProvider.notifier).checkNow(),
      child: child,
    );
  }
}

class UpdatePresentation extends HookWidget {
  const UpdatePresentation({
    super.key,
    required this.release,
    required this.kind,
    required this.child,
    required this.onLater,
    required this.onRetry,
    this.openStore = _openStore,
  });
  final AppRelease? release;
  final UpdateKind kind;
  final Widget child;
  final VoidCallback onLater, onRetry;
  final Future<bool> Function(Uri) openStore;
  static Future<bool> _openStore(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  @override
  Widget build(BuildContext context) {
    final failed = useState(false), opening = useState(false);
    final current = release;
    if (current == null || kind == UpdateKind.none) {
      // Keep the exact Navigator ancestry when a notice appears/disappears.
      return Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: false,
            child: IgnorePointer(ignoring: false, child: child),
          ),
        ],
      );
    }
    final required = kind == UpdateKind.required;
    Future<void> open() async {
      if (opening.value) return;
      opening.value = true;
      var result = false;
      try {
        result = await openStore(Uri.parse(current.storeUrl));
      } catch (_) {}
      if (!context.mounted) return;
      failed.value = !result;
      opening.value = false;
    }

    final card = Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: required ? 0 : 8,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '새 버전으로 함께해요' : '업데이트가 도착했어요',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${current.version} · ${current.message}'),
            if (failed.value)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '스토어를 열지 못했어요. 연결을 확인하거나 스토어에서 CloudBoard를 검색해 주세요.',
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: opening.value ? null : open,
                  child: const Text('업데이트'),
                ),
                if (!required)
                  TextButton(onPressed: onLater, child: const Text('나중에')),
                if (required)
                  TextButton(onPressed: onRetry, child: const Text('다시 확인')),
              ],
            ),
          ],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: required,
          child: IgnorePointer(ignoring: required, child: child),
        ),
        if (required)
          const ModalBarrier(dismissible: false, color: Colors.white),
        SafeArea(
          child: Align(
            alignment: required ? Alignment.center : Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(child: card),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
