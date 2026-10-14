import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history_filters.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/operations_report_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _owner = AuthUser(
  id: 'center-a',
  email: 'coach@example.invalid',
  displayName: '코치',
  photoUrl: null,
);

OperationEvent _event(
  String id, {
  String type = 'device_offline',
  int? at,
  String? recoveryOfEventId,
}) => OperationEvent(
  id: id,
  eventId: id,
  type: type,
  occurredAtMs: at ?? DateTime.now().millisecondsSinceEpoch - 60000,
  deviceId: 'tv-1',
  deviceName: '당시 메인 TV',
  zoneName: '1층 운동실',
  deviceRole: 'display',
  appVersion: '1.1.1+69',
  phase: 'server_connection',
  workoutId: 'class-1',
  workoutName: '기초 체력 수업',
  sessionId: 'session-1',
  scheduled: false,
  scheduledAtMs: null,
  schemaVersion: 2,
  errorId: 'error-1',
  recoveryOfEventId: recoveryOfEventId,
);

Future<void> _mount(
  WidgetTester tester, {
  Stream<OperationEventBatch> Function(OperationEventRange)? stream,
  Size size = const Size(390, 844),
  Stream<AuthUser?>? users,
  ValueChanged<Object?>? support,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: OperationsReportTab()),
      ),
      if (support != null)
        GoRoute(
          path: '/support',
          builder: (_, state) {
            support(state.extra);
            return const Scaffold(body: Text('문의 작성'));
          },
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((ref) => users ?? Stream.value(_owner)),
        operationEventsInRangeProvider.overrideWith(
          (ref, range) =>
              stream?.call(range) ??
              Stream.value(
                OperationEventBatch(
                  events: [_event('disconnect')],
                  isComplete: true,
                ),
              ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return MaterialApp.router(
            theme: XonTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('historical filters include command target and preserve deleted device name', () {
    final command = _event('command').copyWith(
      deviceId: 'phone',
      deviceRole: 'controller',
      targetDeviceIds: ['deleted-tv'],
      targetDeviceNames: {'deleted-tv': '이름 변경 전 TV'},
    );
    expect(filterOperationHistory([command], deviceId: 'deleted-tv'), [
      command,
    ]);
    expect(operationDeviceOptions([command])['deleted-tv'], '이름 변경 전 TV');
    expect(filterOperationHistory([command], workoutId: 'other'), isEmpty);
  });

  testWidgets(
    'loading and query failure do not render zero metrics; retry loads real data',
    (tester) async {
      final pending = StreamController<OperationEventBatch>();
      var calls = 0;
      await _mount(
        tester,
        stream: (_) {
          calls++;
          return calls == 1
              ? pending.stream
              : Stream.value(
                  const OperationEventBatch(events: [], isComplete: true),
                );
        },
      );
      expect(find.text('선택한 기간의 기록을 불러오는 중입니다.'), findsOneWidget);
      expect(find.text('0회 기록'), findsNothing);
      pending.addError(
        StateError('private server error should not be visible'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('운영 기록을 불러오지 못했습니다.'), findsOneWidget);
      expect(find.textContaining('private server error'), findsNothing);
      expect(find.text('0회 기록'), findsNothing);
      await tester.ensureVisible(find.text('다시 시도'));
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('기록 없음'), findsNWidgets(4));
      unawaited(pending.close());
    },
  );

  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets(
      'historical event and linked recovery open readable details at $size',
      (tester) async {
        final disconnect = _event('disconnect');
        final recovery = _event(
          'reconnect',
          type: 'device_online',
          at: disconnect.occurredAtMs + 30000,
          recoveryOfEventId: disconnect.eventId,
        );
        await _mount(
          tester,
          size: size,
          stream: (_) => Stream.value(
            OperationEventBatch(
              events: [disconnect, recovery],
              isComplete: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('operation-event-disconnect'));
        await tester.scrollUntilVisible(
          row,
          350,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.byKey(const ValueKey('operation-event-reconnect')),
          findsNothing,
        );
        expect(find.text('복구 확인 · 재생 영향 확인 불가'), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('operation-event-detail')),
          findsOneWidget,
        );
        expect(find.text('30초'), findsOneWidget);
        expect(
          find.text('원인 확인 필요. 서버 접속이 끊겨도 TV에서 수업이 계속 재생될 수 있습니다.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'range changes query full interval and list paginates beyond 1000',
    (tester) async {
      final ranges = <OperationEventRange>[];
      await _mount(
        tester,
        size: const Size(1280, 1000),
        stream: (range) {
          ranges.add(range);
          return Stream.value(
            OperationEventBatch(
              events: [
                for (var i = 0; i < 1005; i++)
                  _event(
                    'start-$i',
                    type: 'playback_started',
                    at: range.startAtMs + i,
                  ).copyWith(sessionId: 'session-$i'),
              ],
              isComplete: true,
            ),
          );
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('1005회 기록'), findsOneWidget);
      await tester.tap(find.text('최근 7일'));
      await tester.pumpAndSettle();
      expect(
        ranges.last.endBeforeMs - ranges.last.startAtMs,
        const Duration(days: 7).inMilliseconds,
      );
      final more = find.byKey(const ValueKey('operation-history-more'));
      await tester.scrollUntilVisible(
        more,
        5000,
        maxScrolls: 30,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('이전 기록 더 보기 (50/1005)'), findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        more,
        5000,
        maxScrolls: 30,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('이전 기록 더 보기 (100/1005)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'support handoff carries existing error/session IDs and owner scope',
    (tester) async {
      Object? handoff;
      await _mount(tester, support: (value) => handoff = value);
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('operation-event-disconnect'));
      await tester.scrollUntilVisible(
        row,
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      final contact = find.byKey(const ValueKey('operation-contact-support'));
      await tester.scrollUntilVisible(
        contact,
        500,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('operation-event-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(contact);
      await tester.pumpAndSettle();
      expect(handoff, isA<Map<String, Object?>>());
      final details = handoff! as Map<String, Object?>;
      expect(details['_supportOwnerId'], _owner.id);
      expect(details['errorId'], 'error-1');
      expect(details['sessionId'], 'session-1');
      expect(details.containsKey('email'), isFalse);
    },
  );

  testWidgets(
    'an open detail hides account data immediately after account switch',
    (tester) async {
      final users = StreamController<AuthUser?>();
      await _mount(tester, users: users.stream);
      users.add(_owner);
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('operation-event-disconnect'));
      await tester.scrollUntilVisible(
        row,
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      users.add(_owner.copyWith(id: 'center-b'));
      await tester.pumpAndSettle();
      expect(find.text('로그인한 계정에서 기록을 다시 열어 주세요.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('operation-event-detail')),
        findsNothing,
      );
      unawaited(users.close());
    },
  );
}
