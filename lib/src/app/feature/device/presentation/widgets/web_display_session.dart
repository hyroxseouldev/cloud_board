import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/web_display_auth.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Display providers have their own lifetime and credentials. Disposing this
/// scope stops display subscriptions; it never signs the controller out.
class WebDisplaySession extends ConsumerWidget {
  const WebDisplaySession({
    super.key,
    required this.child,
    required this.onReturnToControl,
  });

  final Widget child;
  final VoidCallback onReturnToControl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authStateProvider);
    final ownerId = owner.value?.id;
    if (owner.isLoading || owner.hasError || ownerId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final identity = ref.watch(webDisplayAuthProvider(ownerId));
    ref.listen(webDisplayAuthProvider(ownerId), (previous, next) {
      if (next.hasError && next.error != previous?.error) {
        ref
            .read(errorReporterProvider)
            .capture(
              next.error!,
              next.stackTrace ?? StackTrace.current,
              action: 'pairing.authenticate',
            );
      }
    });
    return identity.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('디스플레이 기기 인증을 준비하지 못했습니다.'),
            TextButton(
              onPressed: () => ref.invalidate(webDisplayAuthProvider(ownerId)),
              child: const Text('다시 시도'),
            ),
            TextButton(
              onPressed: onReturnToControl,
              child: const Text('컨트롤 화면으로 돌아가기'),
            ),
          ],
        ),
      ),
      data: (auth) =>
          _DisplayProviders(key: ValueKey(ownerId), auth: auth, child: child),
    );
  }
}

class _DisplayProviders extends HookWidget {
  const _DisplayProviders({super.key, required this.auth, required this.child});
  final FirebaseAuth auth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A separate root container prevents an already-created controller
    // repository from being reused with the display's anonymous credentials.
    final container = useMemoized(
      () => ProviderContainer(
        overrides: [
          firebaseClientAuthProvider.overrideWith((_) => auth),
          deviceIdProvider.overrideWith(
            (_) async => webDisplayDeviceId(auth.currentUser!.uid),
          ),
        ],
      ),
      [auth],
    );
    useEffect(() => container.dispose, [container]);
    return UncontrolledProviderScope(container: container, child: child);
  }
}
