import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
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
    final owner = ref.watch(firebaseAccountUserProvider);
    final user = owner.value;
    if (owner.isLoading || owner.hasError || user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final formFactor = ref.watch(androidTvProvider);
    if (!formFactor.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    // Native TVs already have a dedicated anonymous identity and paired device
    // ID. Preserve that scope; only signed-in controller accounts need isolation.
    if (user.isAnonymous) return child;
    final ownerId = user.uid;
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
      data: (auth) => _DisplayProviders(
        key: ValueKey(ownerId),
        auth: auth,
        isTv: formFactor.requireValue,
        child: child,
      ),
    );
  }
}

class _DisplayProviders extends HookWidget {
  const _DisplayProviders({
    super.key,
    required this.auth,
    required this.isTv,
    required this.child,
  });
  final FirebaseAuth auth;
  final bool isTv;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A separate root container prevents an already-created controller
    // repository from being reused with the display's anonymous credentials.
    final container = useMemoized(
      () => ProviderContainer(
        overrides: [
          firebaseClientAuthProvider.overrideWith((_) => auth),
          androidTvProvider.overrideWith((_) => isTv),
          // A legacy signed-in TV now has an isolated session. Its first frame
          // stays hidden until the lifecycle in this same scope confirms it.
          tvPlaybackVisibleProvider.overrideWith(
            () => TvPlaybackVisible(initiallyVisible: !isTv),
          ),
          deviceIdProvider.overrideWith(
            (_) async => webDisplayDeviceId(auth.currentUser!.uid),
          ),
        ],
      ),
      [auth, isTv],
    );
    useEffect(() => container.dispose, [container]);
    return UncontrolledProviderScope(container: container, child: child);
  }
}
