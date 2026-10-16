import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/app.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/services/android_class_notifications.dart';
import 'package:cloud_board/src/app/core/services/ios_class_controls.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/presentation/controllers/app_update_controller.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/email_login_screen.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/controllers/billing_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _networkMessage = '로그인 서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.';
const _emailMessage = '이메일 또는 비밀번호를 확인해 주세요.';
const _user = AuthUser(
  id: 'test-user',
  email: '',
  displayName: '테스트',
  photoUrl: null,
);

class _AuthRepository implements AuthRepository {
  Completer<AuthUser>? pending;
  final calls = <String>[];
  Future<AuthUser> attempt(String provider) {
    calls.add(provider);
    pending = Completer<AuthUser>();
    return pending!.future;
  }

  @override
  Future<AuthUser> signInWithApple() => attempt('apple');
  @override
  Future<AuthUser> signInWithGoogle() => attempt('google');
  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      attempt('email');
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Billing extends BillingPurchaseController {
  @override
  BillingActivity build() => const BillingActivity();
  @override
  Future<void> recoverPendingPurchases() async {}
}

class _Updates extends AppUpdateController {
  @override
  Future<({AppRelease release, UpdateKind kind})?> build() async => null;
}

class _Workouts extends WorkoutActionController {
  void fail(Object error) {
    state = const AsyncLoading();
    state = AsyncError(error, StackTrace.current);
  }
}

class _Diagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

void main() {
  void testAppWidgets(String description, WidgetTesterCallback callback) {
    testWidgets(description, (tester) async {
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<({GoRouter router, ProviderContainer container, _Diagnostics sink})>
  mount(
    WidgetTester tester,
    _AuthRepository repository, {
    bool tv = false,
    TargetPlatform platform = TargetPlatform.iOS,
    Size size = const Size(390, 844),
    double scale = 1,
    _Workouts? workouts,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/login/email',
          builder: (_, _) => const EmailLoginScreen(),
        ),
        GoRoute(
          path: '/away',
          builder: (_, _) => const Scaffold(body: Text('다른 화면')),
        ),
      ],
    );
    final sink = _Diagnostics();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        errorReporterProvider.overrideWithValue(ErrorReporter(sink)),
        appRouterProvider.overrideWithValue(router),
        androidTvProvider.overrideWith((ref) async => tv),
        billingPurchaseControllerProvider.overrideWith(_Billing.new),
        storeEntitlementProvider.overrideWith((ref) => Stream.value(null)),
        appUpdateControllerProvider.overrideWith(_Updates.new),
        iosClassControlsProvider.overrideWith((ref) async {}),
        androidClassNotificationsProvider.overrideWith((ref) async => true),
        if (workouts != null)
          workoutActionControllerProvider.overrideWith(() => workouts),
      ],
    );
    addTearDown(() {
      router.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: const XonBoardApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router: router, container: container, sink: sink);
  }

  Future<Offset> tap(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    final position = tester.getCenter(button);
    await tester.tapAt(position);
    await tester.pump();
    return position;
  }

  void expectNotice(WidgetTester tester, String message) {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text(message)),
      findsOneWidget,
    );
    final notice = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(notice.action, isNull);
    expect(notice.backgroundColor, isNull);
    expect(
      Theme.of(tester.element(find.byType(SnackBar)))
          .snackBarTheme
          .backgroundColor,
      AppColors.ink,
    );
    expect(find.text('문의하기'), findsNothing);
    expect(find.text('문제 문의하기'), findsNothing);
    expect(find.text('오류 상세'), findsNothing);
    expect(find.textContaining('오류 코드:'), findsNothing);
    expect(find.textContaining('private-token'), findsNothing);
    expect(tester.takeException(), isNull);
  }

  for (final scenario in [
    (provider: 'apple', tv: false, platform: TargetPlatform.iOS),
    (provider: 'google', tv: false, platform: TargetPlatform.android),
    (provider: 'google', tv: true, platform: TargetPlatform.android),
  ]) {
    testAppWidgets(
      '${scenario.provider} tv=${scenario.tv}: global listener shows one error per attempt, no replay and clears on success',
      (tester) async {
        final repository = _AuthRepository();
        final fixture = await mount(
          tester,
          repository,
          tv: scenario.tv,
          platform: scenario.platform,
        );
        final button = find.text(
          scenario.provider == 'apple' ? 'Apple로 계속하기' : 'Google로 계속하기',
        );
        final position = await tap(tester, button);
        await tester.tapAt(position);
        expect(repository.calls, [scenario.provider]);
        final error = FirebaseAuthException(
          code: 'network-request-failed',
          message: 'private-token',
        );
        repository.pending!.completeError(error);
        await tester.pumpAndSettle();
        expectNotice(tester, _networkMessage);
        expect(fixture.sink.events, hasLength(1));
        tester.element(find.byType(XonBoardApp)).markNeedsBuild();
        tester.element(find.byType(LoginScreen)).markNeedsBuild();
        await tester.pumpAndSettle();
        expectNotice(tester, _networkMessage);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        fixture.router.push('/away');
        await tester.pumpAndSettle();
        fixture.router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        // Even the same error object represents a new failure after a new attempt.
        await tap(tester, button);
        repository.pending!.completeError(error);
        await tester.pumpAndSettle();
        expectNotice(tester, _networkMessage);
        await tap(tester, button);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(_networkMessage), findsNothing);
        repository.pending!.complete(_user);
        await tester.pumpAndSettle();
        expect(find.text(_networkMessage), findsNothing);
        expect(find.text('로그인되었습니다.'), findsOneWidget);
        expect(repository.calls, hasLength(3));
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  for (final cancellation in [
    FirebaseAuthException(code: 'canceled'),
    FirebaseAuthException(code: 'popup-closed-by-user'),
    const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
  ]) {
    testAppWidgets(
      'sign-in cancellation ${cancellation.runtimeType} $cancellation is silent',
      (tester) async {
        final repository = _AuthRepository();
        final fixture = await mount(tester, repository);
        final apple =
            cancellation is FirebaseAuthException &&
            cancellation.code == 'canceled';
        await tap(tester, find.text(apple ? 'Apple로 계속하기' : 'Google로 계속하기'));
        repository.pending!.completeError(cancellation);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(
          fixture.container.read(authControllerProvider).hasError,
          isFalse,
        );
        expect(fixture.sink.events, isEmpty);
      },
    );
  }

  testAppWidgets(
    'email server failure stays single with global listeners, expires, retries and clears on success',
    (tester) async {
      final repository = _AuthRepository();
      final fixture = await mount(tester, repository);
      fixture.router.push('/login/email');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-input')),
        'fixture@example.invalid',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password-input')),
        'private-password',
      );
      final submit = find.byKey(const ValueKey('email-submit'));
      await tap(tester, submit);
      await tester.tap(submit);
      expect(repository.calls, ['email']);
      repository.pending!.completeError(
        FirebaseAuthException(
          code: 'invalid-credential',
          message: 'private-token',
        ),
      );
      await tester.pumpAndSettle();
      expectNotice(tester, _emailMessage);
      expect(
        fixture.sink.events.single.context['firebaseCode'],
        'invalid-credential',
      );
      expect(fixture.sink.events.single.details, isNot(contains('private')));
      tester.element(find.byType(EmailLoginScreen)).markNeedsBuild();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      fixture.router.push('/away');
      await tester.pumpAndSettle();
      fixture.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await tap(tester, submit);
      repository.pending!.completeError(
        FirebaseAuthException(code: 'invalid-credential'),
      );
      await tester.pumpAndSettle();
      expectNotice(tester, _emailMessage);
      await tap(tester, submit);
      repository.pending!.complete(_user);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(repository.calls, hasLength(3));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('password-input')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testAppWidgets(
      'narrow $platform large text notice wraps above keyboard and safe area',
      (tester) async {
        final repository = _AuthRepository();
        await mount(
          tester,
          repository,
          platform: platform,
          size: const Size(320, 568),
          scale: 2,
        );
        await tap(tester, find.text('Google로 계속하기'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        repository.pending!.completeError(
          FirebaseAuthException(code: 'network-request-failed'),
        );
        await tester.pumpAndSettle();
        expectNotice(tester, _networkMessage);
        final rect = tester.getRect(find.byType(SnackBar));
        expect(rect.bottom, lessThanOrEqualTo(348));
        expect(
          tester.getSize(find.text(_networkMessage)).height,
          greaterThan(30),
        );
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        final content = tester.getRect(find.text(_networkMessage));
        expect(content.bottom, lessThanOrEqualTo(568 - 34));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testAppWidgets('common action captures diagnostics without a support click', (
    tester,
  ) async {
    final actions = _Workouts();
    final fixture = await mount(tester, _AuthRepository(), workouts: actions);
    actions.fail(StateError('수업 변경 실패'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, isNull);
    expect(fixture.sink.events.single.context['action'], 'ui.action');
    expect(tester.takeException(), isNull);
  });

  testAppWidgets('login failure visual evidence', (tester) async {
    const directory = String.fromEnvironment('STA185_CAPTURE_DIR');
    if (directory.isEmpty || kIsWeb) return;
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final repository = _AuthRepository();
    await mount(tester, repository);
    await tap(tester, find.text('Apple로 계속하기'));
    repository.pending!.completeError(FirebaseAuthException(code: 'unknown'));
    await tester.pumpAndSettle();
    expectNotice(tester, '로그인을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/login-error-phone.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}
