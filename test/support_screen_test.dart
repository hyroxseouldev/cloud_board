import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/presentation/controllers/support_controller.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/support_ticket_fixture.dart';

Future<void> mountSupport(
  WidgetTester tester,
  SupportFixture fixture, {
  bool signedIn = true,
  Map<String, Object?> initial = const {},
  double scale = 1,
}) async {
  await tester.pumpWidget(
    fixture.app(initialDiagnostics: initial, scale: scale),
  );
  await tester.pump();
  fixture.users.add(signedIn ? supportUser : null);
  await tester.pumpAndSettle();
}

Future<void> tapSupport(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets(
    'attachment preview, failed save preserves input, identical retry receives ticket before email delivery',
    (tester) async {
      final fixture = SupportFixture();
      addTearDown(fixture.dispose);
      await mountSupport(
        tester,
        fixture,
        initial: {
          'errorId': 'actual-error-1',
          'occurredAtMs': 1791986400000,
          'action': 'playback.start',
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('support-message')),
        'TV 3대 준비 뒤 시작을 눌렀는데 실패했어요.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('support-email')),
        'reply@example.com',
      );
      await tapSupport(tester, find.text('스크린샷 첨부 · 선택'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('support-screenshot-preview')),
        findsOneWidget,
      );
      final gate = Completer<SupportTicket>();
      fixture.repository.handler = (_) => gate.future;
      await tapSupport(tester, find.byKey(const ValueKey('support-submit')));
      expect(find.text('접수 확인 중…'), findsOneWidget);
      expect(find.text('문의가 접수됐어요.'), findsNothing);
      expect(fixture.repository.drafts.length, 1);
      await tester.tap(find.byKey(const ValueKey('support-submit')));
      expect(fixture.repository.drafts.length, 1);
      gate.completeError(
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Fixture unavailable',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('support-message')),
            )
            .controller!
            .text,
        contains('TV 3대'),
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('support-email')))
            .controller!
            .text,
        'reply@example.com',
      );
      expect(
        find.byKey(const ValueKey('support-screenshot-preview')),
        findsOneWidget,
      );
      fixture.repository.handler = (_) async => supportReceipt;
      await tapSupport(tester, find.byKey(const ValueKey('support-submit')));
      await tester.pumpAndSettle();
      expect(find.text('문의가 접수됐어요.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('support-ticket-number')),
        findsOneWidget,
      );
      expect(find.textContaining('운영자 알림 상태를 확인 중'), findsOneWidget);
      expect(
        fixture.repository.drafts[0].requestId,
        fixture.repository.drafts[1].requestId,
      );
      expect(
        fixture.repository.drafts[1].diagnostics['errorId'],
        'actual-error-1',
      );
      fixture.repository.handler = (_) async =>
          supportReceipt.copyWith(notificationStatus: 'sent');
      await tapSupport(tester, find.text('알림 상태 다시 확인'));
      await tester.pumpAndSettle();
      expect(
        fixture.repository.drafts[2].requestId,
        fixture.repository.drafts[0].requestId,
      );
      expect(find.textContaining('운영자 알림을 발송했어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );

  testWidgets(
    'general inquiry has honest unknown diagnostics and no attachment requirement at 2x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = SupportFixture(diagnostics: {});
      addTearDown(fixture.dispose);
      await mountSupport(tester, fixture, scale: 2);
      await tester.enterText(
        find.byKey(const ValueKey('support-message')),
        '사용 방법이 궁금해요.',
      );
      await tapSupport(tester, find.text('함께 보낼 진단 정보'));
      await tester.pumpAndSettle();
      expect(find.textContaining('오류 ID: 미확인'), findsOneWidget);
      await tapSupport(tester, find.byKey(const ValueKey('support-submit')));
      await tester.pumpAndSettle();
      expect(fixture.repository.drafts.single.attachment, isNull);
      expect(fixture.repository.drafts.single.diagnostics, isEmpty);
      expect(find.text('문의가 접수됐어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );

  testWidgets(
    'image picker cancel and validation failure leave message intact',
    (tester) async {
      final fixture = SupportFixture();
      addTearDown(fixture.dispose);
      await mountSupport(tester, fixture);
      await tester.enterText(
        find.byKey(const ValueKey('support-message')),
        '문의 작성 중',
      );
      fixture.picker.value = null;
      await tapSupport(tester, find.text('스크린샷 첨부 · 선택'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('support-screenshot-preview')),
        findsNothing,
      );
      fixture.picker.error = const FormatException('스크린샷은 5MB 이하로 첨부해 주세요.');
      await tapSupport(tester, find.text('스크린샷 첨부 · 선택'));
      await tester.pumpAndSettle();
      expect(find.text('스크린샷은 5MB 이하로 첨부해 주세요.'), findsOneWidget);
      expect(
        fixture.container.read(supportControllerProvider).message,
        '문의 작성 중',
      );
      expect(fixture.repository.drafts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );

  testWidgets(
    'TV points to paired controller and signed-out screen never exposes send',
    (tester) async {
      final tv = SupportFixture(tv: true);
      addTearDown(tv.dispose);
      await mountSupport(tester, tv);
      expect(find.text('연결된 휴대폰이나 웹에서 문의해 주세요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('support-submit')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tv.dispose();
      final signedOut = SupportFixture();
      addTearDown(signedOut.dispose);
      await mountSupport(tester, signedOut, signedIn: false);
      expect(find.text('로그인하기'), findsOneWidget);
      expect(find.byKey(const ValueKey('support-submit')), findsNothing);
      expect(signedOut.repository.drafts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await signedOut.dispose();
    },
  );

  testWidgets(
    'production error CTA carries the existing actual diagnostic ID without raw error',
    (tester) async {
      final sink = _Sink();
      final reporter = ErrorReporter(sink);
      final error = StateError('raw secret body');
      final recorded = reporter.capture(
        error,
        StackTrace.current,
        action: 'playback.start',
        context: {'version': '1.1.1'},
      );
      Map<String, Object?>? extra;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: ErrorDetailsButton(error: error)),
          ),
          GoRoute(
            path: '/support',
            builder: (_, state) {
              extra = state.extra as Map<String, Object?>;
              return const Scaffold(body: Text('문의 작성 화면'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((_) async => false),
            authStateProvider.overrideWith((_) => Stream.value(supportUser)),
            errorReporterProvider.overrideWithValue(reporter),
          ],
          child: MaterialApp.router(
            theme: XonTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('문제 문의하기'));
      await tester.pumpAndSettle();
      expect(extra?['errorId'], recorded.id);
      expect(extra?['action'], 'playback.start');
      expect(extra.toString(), isNot(contains('raw secret body')));
      expect(sink.events.length, 1);
      expect(find.text('문의 작성 화면'), findsOneWidget);
    },
  );
}

class _Sink implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async {
    events.add(event);
  }
}
