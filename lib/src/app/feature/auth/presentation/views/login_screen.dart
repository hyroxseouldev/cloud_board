import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isTv = ref.watch(androidTvProvider).value ?? false;
    final loginFocusNode = useFocusNode();
    useEffect(() {
      if (!isTv) return null;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (loginFocusNode.canRequestFocus) loginFocusNode.requestFocus();
      });
      return () {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      };
    }, [isTv, loginFocusNode]);

    return AsyncActionOverlay(
      isLoading: authState.isLoading,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CloudBoard',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isTv
                        ? '매장 계정으로 로그인하면 이 TV가 디스플레이로 시작됩니다.'
                        : '운동 루틴을 한 곳에서 관리하세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (isTv) ...[
                    const SizedBox(height: 20),
                    const Icon(Icons.tv_rounded, size: 72),
                    const SizedBox(height: 8),
                    Text(
                      '리모컨의 확인 버튼으로 로그인하세요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    autofocus: isTv,
                    focusNode: loginFocusNode,
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                    icon: authState.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      authState.isLoading ? '로그인 중...' : 'Google로 계속하기',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
