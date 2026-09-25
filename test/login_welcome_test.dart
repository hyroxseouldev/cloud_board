import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _PendingRepository implements AuthRepository {
  final result = Completer<AuthUser>();
  int calls = 0;
  @override
  Future<AuthUser> signInWithApple() {
    calls++;
    return result.future;
  }

  @override
  Future<AuthUser> signInWithGoogle() => signInWithApple();
  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();
  @override
  Future<void> signOut() async {}
}

void main() {
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    _PendingRepository? repository,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          androidTvProvider.overrideWith((ref) async => false),
          if (repository != null)
            authRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pending sign-in stays in its button, blocks duplicates, and recovers after cancel',
    (tester) async {
      final repository = _PendingRepository();
      await mount(tester, repository: repository);
      await tester.tap(find.text('Apple로 계속하기'));
      await tester.tap(find.text('Apple로 계속하기'));
      await tester.pump();
      expect(repository.calls, 1);
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((button) => button.onPressed == null),
        isTrue,
      );
      repository.result.completeError(FirebaseAuthException(code: 'canceled'));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((button) => button.onPressed != null),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'small phone with large text can reach account help without overflow',
    (tester) async {
      await mount(tester, size: const Size(320, 568), scale: 1.5);
      await tester.ensureVisible(find.text('계정 안내'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계정 안내'));
      await tester.pumpAndSettle();
      expect(find.text('기존 계정으로 로그인하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('기존 계정으로 로그인하기'), findsNothing);
    },
  );
}
