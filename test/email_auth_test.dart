import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/email_auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/email_login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Repository implements AuthRepository {
  final calls = <(String, String, String?)>[];
  Completer<void>? pending;
  Object? failure;
  Future<AuthUser> _perform(
    String action,
    String email,
    String? password,
  ) async {
    calls.add((action, email, password));
    await pending?.future;
    if (failure != null) throw failure!;
    return AuthUser(
      id: 'email-user',
      email: email,
      displayName: '사용자',
      photoUrl: null,
      needsOnboarding: true,
      hasPassword: true,
    );
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      _perform('login', email, password);
  @override
  Future<AuthUser> createEmailAccount(String email, String password) =>
      _perform('signup', email, password);
  @override
  Future<void> sendPasswordReset(String email) async =>
      _perform('reset', email, null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth({this.user});
  final _User? user;
  final calls = <String>[];
  String? resetError;
  @override
  User? get currentUser => user;
  @override
  Future<void> setLanguageCode(String? languageCode) async {
    calls.add(languageCode!);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    calls.add(email);
    if (resetError != null) throw FirebaseAuthException(code: resetError!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  final calls = <String>[];
  AuthCredential? credential;
  bool fail = false;
  @override
  String get email => 'coach@example.com';
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [_PasswordInfo()];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    this.credential = credential;
    calls.add('reauth');
    if (fail) throw FirebaseAuthException(code: 'wrong-password');
    return _Credential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    calls.add('refresh');
    return 'token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PasswordInfo implements UserInfo {
  @override
  String get providerId => 'password';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer create(_Repository repo) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = container.listen(emailAuthControllerProvider, (_, _) {});
    addTearDown(() {
      sub.close();
      container.dispose();
    });
    return container;
  }

  test('email trims whitespace, preserves password, and coalesces duplicate operations', () async {
    final repo = _Repository()..pending = Completer<void>();
    final container = create(repo);
    final controller = container.read(emailAuthControllerProvider.notifier);
    final pending = controller.signIn(' coach@example.com ', ' password ');
    await controller.createAccount('other@example.com', 'another');
    await controller.resetPassword('other@example.com');
    expect(repo.calls, [('login', 'coach@example.com', ' password ')]);
    repo.pending!.complete();
    await pending;
    expect(container.read(emailAuthControllerProvider).hasError, isFalse);
  });

  for (final code in [
    'wrong-password',
    'invalid-credential',
    'user-not-found',
    'email-already-in-use',
    'weak-password',
    'too-many-requests',
    'network-request-failed',
    'operation-not-allowed',
  ]) {
    test('handles $code without exposing exception payload', () async {
      final repo = _Repository()
        ..failure = FirebaseAuthException(
          code: code,
          message: 'private-provider-payload',
        );
      final container = create(repo);
      await container
          .read(emailAuthControllerProvider.notifier)
          .signIn('coach@example.com', 'private-password');
      final state = container.read(emailAuthControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isA<EmailAuthFailure>());
      expect(state.error.toString(), isNot(contains('private')));
      if ([
        'wrong-password',
        'invalid-credential',
        'user-not-found',
      ].contains(code)) {
        expect(state.error.toString(), '이메일 또는 비밀번호를 확인해 주세요.');
      }
    });
  }

  test(
    'password reset hides unknown accounts but reports transport failures',
    () async {
      final auth = _Auth()..resetError = 'user-not-found';
      final source = FirebaseAuthDataSource(auth, GoogleSignIn.instance);
      await source.sendPasswordReset(' nobody@example.com ');
      expect(auth.calls, ['ko', 'nobody@example.com']);
      auth.resetError = 'network-request-failed';
      await expectLater(
        source.sendPasswordReset('coach@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );

  test(
    'deletion reauthenticates password identity before refreshing token',
    () async {
      final user = _User();
      final source = FirebaseAuthDataSource(
        _Auth(user: user),
        GoogleSignIn.instance,
      );
      await expectLater(
        source.prepareAccountDeletion(),
        throwsA(isA<StateError>()),
      );
      expect(user.calls, isEmpty);
      await source.prepareAccountDeletion(password: ' secret ');
      expect(user.calls, ['reauth', 'refresh']);
      expect((user.credential as EmailAuthCredential).password, ' secret ');
      user.calls.clear();
      user.fail = true;
      await expectLater(
        source.prepareAccountDeletion(password: 'wrong'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(user.calls, ['reauth']);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    _Repository repo, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const EmailLoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final emailInput = find.byKey(const ValueKey('email-input'));
  final passwordInput = find.byKey(const ValueKey('password-input'));
  final submit = find.byKey(const ValueKey('email-submit'));
  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'signup validates confirmation and uses explicit create-account action',
    (tester) async {
      final repo = _Repository();
      await mount(tester, repo);
      await press(tester, find.text('처음이신가요? 이메일로 가입하기'));
      await tester.enterText(emailInput, ' coach@example.com ');
      await tester.enterText(passwordInput, 'password-123');
      await tester.enterText(
        find.byKey(const ValueKey('password-confirmation')),
        'different',
      );
      await press(tester, submit);
      expect(repo.calls, isEmpty);
      expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('password-confirmation')),
        'password-123',
      );
      await press(tester, submit);
      expect(repo.calls, [('signup', 'coach@example.com', 'password-123')]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login validates fields, blocks duplicate taps and can retry a failure',
    (tester) async {
      final repo = _Repository()..pending = Completer<void>();
      await mount(tester, repo);
      await press(tester, submit);
      expect(repo.calls, isEmpty);
      await tester.enterText(emailInput, 'coach@example.com');
      await tester.enterText(passwordInput, 'old-six');
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit);
      expect(repo.calls.length, 1);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      repo.failure = FirebaseAuthException(code: 'invalid-credential');
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      repo.failure = null;
      await press(tester, submit);
      expect(repo.calls.length, 2);
    },
  );

  testWidgets(
    'reset uses only email, shows neutral confirmation, and retains address on return',
    (tester) async {
      final repo = _Repository();
      await mount(tester, repo);
      await tester.enterText(emailInput, 'coach@example.com');
      await tester.enterText(passwordInput, 'secret');
      await press(tester, find.text('비밀번호를 잊으셨나요?'));
      expect(passwordInput, findsNothing);
      await press(tester, submit);
      expect(repo.calls, [('reset', 'coach@example.com', null)]);
      expect(find.textContaining('재설정 가능한 계정이라면'), findsOneWidget);
      await press(tester, find.text('로그인으로 돌아가기'));
      expect(
        tester.widget<TextFormField>(emailInput).controller!.text,
        'coach@example.com',
      );
      expect(
        tester.widget<TextFormField>(passwordInput).controller!.text,
        isEmpty,
      );
      expect(find.textContaining('재설정 가능한 계정이라면'), findsNothing);
    },
  );

  testWidgets(
    'small viewport with keyboard and large text keeps signup reachable',
    (tester) async {
      await mount(
        tester,
        _Repository(),
        size: const Size(320, 568),
        scale: 1.5,
      );
      await press(tester, find.text('처음이신가요? 이메일로 가입하기'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(submit.hitTestable(), findsOneWidget);
    },
  );
}
