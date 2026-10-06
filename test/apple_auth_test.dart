import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/auth_error_message.dart';
import 'package:cloud_board/src/app/feature/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';

class _Repository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final result = Completer<AuthUser>();
  int calls = 0;
  @override
  Future<AuthUser> signInWithApple() {
    calls++;
    return result.future;
  }

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();
  @override
  Future<void> signOut() async {}
  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();
}

class _DiagnosticSink implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

class _Info implements UserInfo {
  _Info(this.providerId);
  @override
  final String providerId;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.code);
  final String? code;
  @override
  AdditionalUserInfo get additionalUserInfo =>
      AdditionalUserInfo(isNewUser: false, authorizationCode: code);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.calls, {this.code = 'fresh-code', this.cancel = false});
  final List<String> calls;
  final String? code;
  final bool cancel;
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [_Info('apple.com')];
  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    expect(provider.providerId, 'apple.com');
    calls.add('reauth');
    if (cancel) throw FirebaseAuthException(code: 'canceled');
    return _Credential(code);
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    calls.add('refresh');
    return 'test-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(this.currentUser, this.calls, {this.revokeFails = false});
  @override
  final User currentUser;
  final List<String> calls;
  final bool revokeFails;
  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    expect(code, 'fresh-code');
    calls.add('revoke');
    if (revokeFails) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Apple deletion reauthenticates, revokes authorization, then refreshes Firebase token', () async {
    final calls = <String>[];
    final ds = FirebaseAuthDataSource(
      _Auth(_User(calls), calls),
      GoogleSignIn.instance,
    );
    await ds.prepareAccountDeletion();
    expect(calls, ['reauth', 'revoke', 'refresh']);
    await ds.signOut();
    expect(
      calls.last,
      'signOut',
    ); // No Google initialization for Apple-only users.
  });
  for (final scenario in ['cancel', 'missing-code', 'revoke-failure']) {
    test('Apple deletion stops on $scenario', () async {
      final calls = <String>[];
      final ds = FirebaseAuthDataSource(
        _Auth(
          _User(
            calls,
            code: scenario == 'missing-code' ? null : 'fresh-code',
            cancel: scenario == 'cancel',
          ),
          calls,
          revokeFails: scenario == 'revoke-failure',
        ),
        GoogleSignIn.instance,
      );
      await expectLater(ds.prepareAccountDeletion(), throwsA(anything));
      expect(calls, isNot(contains('refresh')));
    });
  }
  test(
    'Apple sign-in prevents duplicate requests and treats cancel as no action',
    () async {
      final repo = _Repository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWith((ref) => repo)],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      final pending = controller.signInWithApple();
      await controller.signInWithApple();
      expect(repo.calls, 1);
      repo.result.completeError(FirebaseAuthException(code: 'canceled'));
      await pending;
      expect(container.read(authControllerProvider).hasError, false);
      expect(container.read(authControllerProvider).value, isNull);
    },
  );
  test('credential conflict tells users to use existing login without automatic merge', () async {
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);
    final pending = container
        .read(authControllerProvider.notifier)
        .signInWithApple();
    repo.result.completeError(
      FirebaseAuthException(code: 'account-exists-with-different-credential'),
    );
    await pending;
    expect(
      authErrorMessage(container.read(authControllerProvider).error),
      contains('가입한 로그인 방식'),
    );
  });
  test(
    'Apple failures retain the original error, native reason and stack',
    () async {
      final repo = _Repository();
      final sink = _DiagnosticSink();
      final reporter = ErrorReporter(sink);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => repo),
          errorReporterProvider.overrideWith((ref) => reporter),
        ],
      );
      addTearDown(container.dispose);
      final error = FirebaseAuthException(
        code: 'unknown',
        message:
            'com.apple.AuthenticationServices.AuthorizationError error 1000',
      );
      final stack = StackTrace.fromString(
        'native Apple authorization callback',
      );
      final pending = container
          .read(authControllerProvider.notifier)
          .signInWithApple();
      repo.result.completeError(error, stack);
      await pending;
      final state = container.read(authControllerProvider);
      expect(identical(state.error, error), isTrue);
      expect(identical(state.stackTrace, stack), isTrue);
      expect(sink.events.single.code, 'firebase_auth/unknown');
      expect(sink.events.single.context['action'], 'auth.signInWithApple');
      expect(sink.events.single.details, contains('error 1000'));
      expect(sink.events.single.details, isNot(contains('Bad state')));
    },
  );
  testWidgets(
    'failed Apple login keeps details available and copies a redacted report',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository();
      final sink = _DiagnosticSink();
      final reporter = ErrorReporter(
        sink,
        defaults: {'platform': 'iOS', 'version': '1.0.0', 'build': '548'},
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((ref) async => false),
            authRepositoryProvider.overrideWith((ref) => repo),
            errorReporterProvider.overrideWith((ref) => reporter),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apple로 계속하기'));
      await tester.tap(find.text('Apple로 계속하기'));
      await tester.pump();
      repo.result.completeError(
        FirebaseAuthException(
          code: 'unknown',
          message: 'AuthorizationError error 1000 coach@example.com token=private-token',
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('오류 코드: firebase_auth/unknown'), findsOneWidget);
      await tester.ensureVisible(find.text('오류 상세'));
      await tester.tap(find.text('오류 상세'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('AuthorizationError error 1000'),
        findsOneWidget,
      );
      expect(find.textContaining('build: 548'), findsOneWidget);
      await tester.tap(find.text('복사'));
      await tester.pumpAndSettle();
      expect(copied, contains('auth.signInWithApple'));
      expect(copied, contains('firebase_auth/unknown'));
      expect(copied, isNot(contains('coach@example.com')));
      expect(copied, isNot(contains('private-token')));
      expect(sink.events, hasLength(1));
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('login options fit phone on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [androidTvProvider.overrideWith((ref) async => false)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google로 계속하기'), findsOneWidget);
      expect(
        find.text('Apple로 계속하기'),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
