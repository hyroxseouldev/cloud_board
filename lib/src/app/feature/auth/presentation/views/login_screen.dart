import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isTv = ref.watch(androidTvProvider).value ?? false;
    final loginFocusNode = useFocusNode();
    final signingInWith = useState<String?>(null);
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
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

    Future<void> signIn(String provider) async {
      if (authState.isLoading || signingInWith.value != null) return;
      signingInWith.value = provider;
      try {
        final controller = ref.read(authControllerProvider.notifier);
        if (provider == 'apple') {
          await controller.signInWithApple();
        } else {
          await controller.signInWithGoogle();
        }
      } finally {
        if (context.mounted) signingInWith.value = null;
      }
    }

    final busy = authState.isLoading || signingInWith.value != null;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 700;
            final artworkHeight = (constraints.maxHeight * .31).clamp(
              150.0,
              260.0,
            );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compactHeight ? 20 : 32,
                        24,
                        20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'CloudBoard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: compactHeight ? 16 : 24),
                          ExcludeSemantics(
                            child: Image.asset(
                              'assets/images/login_welcome.png',
                              height: artworkHeight,
                              fit: BoxFit.contain,
                              // The decorative image must never block sign-in.
                              errorBuilder: (_, _, _) =>
                                  SizedBox(height: artworkHeight),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isTv ? '우리 센터의 화면을 준비해요.' : '반가워요,',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (!isTv)
                            const Text(
                              'CloudBoard에 오신 걸 환영해요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                letterSpacing: -.6,
                                color: AppColors.ink,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            isTv
                                ? '매장 계정으로 로그인하면 이 TV가 디스플레이로 시작됩니다.'
                                : '우리 센터의 수업을 함께 준비해요.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: AppColors.muted,
                            ),
                          ),
                          SizedBox(height: compactHeight ? 24 : 36),
                          Text(
                            isTv
                                ? '리모컨의 확인 버튼으로 로그인하세요.'
                                : '로그인하고 수업을 준비해 보세요.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (showApple) ...[
                            _SignInButton(
                              provider: 'Apple',
                              dark: true,
                              loading: signingInWith.value == 'apple',
                              icon: const Icon(Icons.apple, size: 25),
                              onPressed: busy ? null : () => signIn('apple'),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _SignInButton(
                            provider: 'Google',
                            loading: signingInWith.value == 'google',
                            focusNode: loginFocusNode,
                            autofocus: isTv,
                            icon: Image.asset(
                              'assets/images/google_g.png',
                              width: 22,
                              height: 22,
                              excludeFromSemantics: true,
                            ),
                            onPressed: busy ? null : () => signIn('google'),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            '기존 회원은 이전 로그인 방법을 선택해 주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.muted,
                            ),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _showAccountHelp(context),
                              child: const Text(
                                '계정 안내',
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showAccountHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AppAlertDialog(
    title: const Text('기존 계정으로 로그인하기'),
    content: const Text(
      '기존 워크아웃을 이용하려면 가입할 때 사용한 로그인 방법을 선택해 주세요.\n\n'
      'Apple의 이메일 숨기기를 사용하거나 다른 로그인 방법을 선택하면 별도 계정이 만들어질 수 있습니다. '
      '계정은 자동으로 합쳐지지 않습니다.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('확인'),
      ),
    ],
  ),
);

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.provider,
    required this.icon,
    required this.onPressed,
    this.dark = false,
    this.loading = false,
    this.focusNode,
    this.autofocus = false,
  });

  final String provider;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool dark;
  final bool loading;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    focusNode: focusNode,
    autofocus: autofocus,
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: dark ? Colors.black : Colors.white,
      foregroundColor: dark ? Colors.white : const Color(0xFF1F1F1F),
      disabledBackgroundColor: dark ? Colors.black : Colors.white,
      disabledForegroundColor: dark ? Colors.white70 : AppColors.muted,
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      side: BorderSide(color: dark ? Colors.black : const Color(0xFF747775)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    icon: loading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: dark ? Colors.white : AppColors.accent,
            ),
          )
        : icon,
    label: Text(loading ? '$provider 로그인 중...' : '$provider로 계속하기'),
  );
}
