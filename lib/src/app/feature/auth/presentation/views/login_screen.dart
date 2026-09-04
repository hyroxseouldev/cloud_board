import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !identical(previous?.error, next.error)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인에 실패했습니다: ${next.error}')));
      }
    });

    return Scaffold(
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
                  'XON BOARD',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '운동 루틴을 한 곳에서 관리하세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(
                    authState.isLoading ? '로그인 중...' : 'Google로 계속하기',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
