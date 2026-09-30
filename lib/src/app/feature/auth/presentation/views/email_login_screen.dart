import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/email_auth_controller.dart';

enum _EmailMode { login, signup, reset }

class EmailLoginScreen extends HookConsumerWidget {
  const EmailLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = useState(_EmailMode.login);
    final email = useTextEditingController();
    final password = useTextEditingController();
    final confirmation = useTextEditingController();
    final obscure = useState(true);
    final formKey = useMemoized(() => GlobalKey<FormState>(), [mode.value]);
    final action = ref.watch(emailAuthControllerProvider);
    final controller = ref.read(emailAuthControllerProvider.notifier);
    final busy = action.isLoading;
    final signup = mode.value == _EmailMode.signup;
    final reset = mode.value == _EmailMode.reset;
    final title = signup
        ? '이메일로 가입하기'
        : reset
        ? '비밀번호 재설정'
        : '이메일로 로그인';

    ref.listen(emailAuthControllerProvider, (previous, next) {
      if (previous?.isLoading == true &&
          next.hasValue &&
          !next.isLoading &&
          !reset) {
        TextInput.finishAutofillContext();
        password.clear();
        confirmation.clear();
      }
    });

    void changeMode(_EmailMode next) {
      if (busy) return;
      controller.clear();
      password.clear();
      confirmation.clear();
      obscure.value = true;
      mode.value = next;
    }

    Future<void> submit() async {
      if (busy || !(formKey.currentState?.validate() ?? false)) return;
      FocusScope.of(context).unfocus();
      if (reset) {
        await controller.resetPassword(email.text);
      } else if (signup) {
        await controller.createAccount(email.text, password.text);
      } else {
        await controller.signIn(email.text, password.text);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        signup
                            ? '함께 수업을 준비해요.'
                            : reset
                            ? '다시 시작할 수 있도록.'
                            : '다시 만나 반가워요.',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        signup
                            ? '가입 후 휴대폰 인증과 센터 설정을 이어서 진행해요.'
                            : reset
                            ? '가입한 이메일로 비밀번호 재설정 링크를 보내드려요.'
                            : '가입한 이메일과 비밀번호를 입력해 주세요.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        key: const ValueKey('email-input'),
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: reset
                            ? TextInputAction.done
                            : TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          hintText: 'name@example.com',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return '이메일을 입력해 주세요.';
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(text)) {
                            return '이메일 주소를 확인해 주세요.';
                          }
                          return null;
                        },
                        onFieldSubmitted: reset ? (_) => submit() : null,
                      ),
                      if (!reset) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const ValueKey('password-input'),
                          controller: password,
                          enabled: !busy,
                          obscureText: obscure.value,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            signup
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: signup
                              ? TextInputAction.next
                              : TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            helperText: signup ? '8자 이상으로 입력해 주세요.' : null,
                            suffixIcon: IconButton(
                              tooltip: obscure.value ? '비밀번호 보기' : '비밀번호 숨기기',
                              onPressed: busy
                                  ? null
                                  : () => obscure.value = !obscure.value,
                              icon: Icon(
                                obscure.value
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해 주세요.';
                            }
                            if (signup && value.length < 8) {
                              return '비밀번호는 8자 이상 입력해 주세요.';
                            }
                            return null;
                          },
                          onFieldSubmitted: signup ? null : (_) => submit(),
                        ),
                      ],
                      if (signup) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const ValueKey('password-confirmation'),
                          controller: confirmation,
                          enabled: !busy,
                          obscureText: obscure.value,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: '비밀번호 확인',
                          ),
                          validator: (value) =>
                              value != password.text || (value?.isEmpty ?? true)
                              ? '비밀번호가 일치하지 않습니다.'
                              : null,
                          onFieldSubmitted: (_) => submit(),
                        ),
                      ],
                      if (action.hasError || action.value != null) ...[
                        const SizedBox(height: 20),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            action.hasError
                                ? action.error.toString()
                                : action.value!,
                            style: TextStyle(
                              color: action.hasError
                                  ? Theme.of(context).colorScheme.error
                                  : AppColors.accent,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        key: const ValueKey('email-submit'),
                        onPressed: busy ? null : submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                        child: busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                signup
                                    ? '회원가입'
                                    : reset
                                    ? '재설정 링크 보내기'
                                    : '로그인',
                              ),
                      ),
                      const SizedBox(height: 12),
                      if (mode.value == _EmailMode.login) ...[
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(_EmailMode.reset),
                          child: const Text('비밀번호를 잊으셨나요?'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(_EmailMode.signup),
                          child: const Text('처음이신가요? 이메일로 가입하기'),
                        ),
                      ] else
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => changeMode(_EmailMode.login),
                          child: const Text('로그인으로 돌아가기'),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Apple·Google로 가입했다면 이전 화면에서 같은 로그인 방법을 선택해 주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
