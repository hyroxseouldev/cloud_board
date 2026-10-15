import 'package:cloud_board/src/app/core/router/auth_entry_routes.dart';
import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/exploration_routes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/core/widgets/welcome_motion.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/widgets/auth_error_notice.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key, this.starter, this.purpose, this.returnTo});
  final StarterWorkout? starter;
  final String? purpose;
  final String? returnTo;

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
    if (!isTv) {
      return _QuietWelcome(
        starter: starter,
        busy: busy,
        showApple: showApple,
        signingInWith: signingInWith.value,
        onExplore: () => context.push(
          starterLocation('/explore', starter, purpose: purpose),
        ),
        onApple: () => signIn('apple'),
        onGoogle: () => signIn('google'),
        onEmail: () => context.push(
          withEntryReturn(
            starterLocation('/login/email', starter, purpose: purpose),
            returnTo,
          ),
        ),
        onAccountHelp: () => _showAccountHelp(context),
        errorNotice: authState.hasError
            ? AuthErrorNotice(
                error: authState.error!,
                stack: authState.stackTrace,
              )
            : null,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 700;
            final artworkHeight = (constraints.maxHeight * .22).clamp(
              120.0,
              180.0,
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
                            AppBrand.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.3,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: compactHeight ? 16 : 24),
                          WelcomeMotion(
                            child: ExcludeSemantics(
                              child: SizedBox(
                                height: artworkHeight,
                                child: Center(
                                  child: SoftRhythmMark(
                                    size: artworkHeight * .78,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          WelcomeMotion(
                            delayFraction: .12,
                            child: Text(
                              isTv
                                  ? '우리 센터의 화면을 준비해요.'
                                  : '휴대폰으로 준비하고\nTV에서 함께 운동해요.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                letterSpacing: -0.26,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isTv ? '매장 계정으로 로그인하면 이 TV가 디스플레이로 시작됩니다.' : '운동 화면과 타이머를 한 수업으로 준비해요.\nTV 없이 예시부터 체험해 보세요.',
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
                                : starter == null
                                ? '내 수업을 저장하려면 로그인해 주세요.'
                                : '${starter!.title} 선택을 이어서 진행해요. 로그인만으로 체험이 시작되지는 않아요.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (showApple) ...[
                            WelcomeMotion(
                              delayFraction: .22,
                              child: _SignInButton(
                                provider: 'Apple',
                                dark: true,
                                loading: signingInWith.value == 'apple',
                                icon: const Icon(Icons.apple, size: 25),
                                onPressed: busy ? null : () => signIn('apple'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          WelcomeMotion(
                            delayFraction: .28,
                            child: _SignInButton(
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
                          ),
                          const SizedBox(height: 12),
                          _SignInButton(
                            provider: '이메일',
                            icon: const Icon(
                              Icons.mail_outline_rounded,
                              size: 22,
                            ),
                            onPressed: busy
                                ? null
                                : () => context.push(
                                    withEntryReturn(
                                      starterLocation(
                                        '/login/email',
                                        starter,
                                        purpose: purpose,
                                      ),
                                      returnTo,
                                    ),
                                  ),
                          ),
                          if (authState.hasError) ...[
                            const SizedBox(height: 16),
                            AuthErrorNotice(
                              error: authState.error!,
                              stack: authState.stackTrace,
                            ),
                          ],
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

/// Mobile welcome only. TV retains its focused remote-friendly sign-in layout.
class _QuietWelcome extends StatelessWidget {
  const _QuietWelcome({
    required this.starter,
    required this.busy,
    required this.showApple,
    required this.signingInWith,
    required this.onExplore,
    required this.onApple,
    required this.onGoogle,
    required this.onEmail,
    required this.onAccountHelp,
    this.errorNotice,
  });

  final StarterWorkout? starter;
  final bool busy, showApple;
  final String? signingInWith;
  final VoidCallback onExplore, onApple, onGoogle, onEmail, onAccountHelp;
  final Widget? errorNotice;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 740 || showApple;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, compact ? 24 : 62, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          AppBrand.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.24,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 58),
                        WelcomeMotion(
                          child: Center(
                            child: SizedBox(
                              height: compact ? 92 : 136,
                              child: Center(
                                child: SoftRhythmMark(size: compact ? 92 : 112),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 22),
                        const WelcomeMotion(
                          delayFraction: .12,
                          child: Text(
                            '오늘의 수업을,\n조금 더 여유롭게.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.28,
                              height: 1.35,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 20),
                        const Text(
                          '운동과 타이머를 준비하고\n연결한 TV에서 진행하세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                        SizedBox(height: compact ? 24 : 34),
                        FilledButton.icon(
                          key: const ValueKey('explore-without-account'),
                          onPressed: busy ? null : onExplore,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.play_circle_outline),
                          label: Text(
                            starter == null ? '예시 수업 둘러보기' : '선택한 예시로 돌아가기',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '계정·TV 없이 먼저 체험할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                        if (starter != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${starter!.title} 선택을 이어가요. 내 수업 저장을 위해 로그인해 주세요.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (showApple) ...[
                          _SignInButton(
                            provider: 'Apple',
                            dark: true,
                            loading: signingInWith == 'apple',
                            icon: const Icon(Icons.apple, size: 25),
                            onPressed: busy ? null : onApple,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SignInButton(
                          provider: 'Google',
                          loading: signingInWith == 'google',
                          icon: Image.asset(
                            'assets/images/google_g.png',
                            width: 22,
                            height: 22,
                            excludeFromSemantics: true,
                          ),
                          onPressed: busy ? null : onGoogle,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const ValueKey('email-sign-in'),
                          onPressed: busy ? null : onEmail,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text(
                            '이메일로 로그인',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (errorNotice != null) ...[
                          const SizedBox(height: 12),
                          errorNotice!,
                        ],
                        SizedBox(height: compact ? 20 : 44),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: busy ? null : onAccountHelp,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text(
                            '기존 계정 로그인 안내',
                            style: TextStyle(
                              fontSize: 13,
                              decoration: TextDecoration.underline,
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
      // Provider buttons keep their existing palette, including pending states.
      disabledForegroundColor: dark ? Colors.white70 : const Color(0xFF777683),
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
              color: dark ? Colors.white : const Color(0xFF77729D),
            ),
          )
        : icon,
    label: Text(loading ? '$provider 로그인 중...' : '$provider로 계속하기'),
  );
}
