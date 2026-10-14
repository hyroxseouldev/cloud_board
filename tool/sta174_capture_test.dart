// Production widgets + deterministic local fixtures. No Firebase/network writes.
// Run: fvm flutter test --no-pub tool/sta174_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/store_operations_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/operations_report_tab.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/more_screen.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/controllers/update_news_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test/support/workout_catalog_fixture.dart';

const _owner = AuthUser(
  id: 'capture-center',
  email: 'capture@example.invalid',
  displayName: '김코치',
  photoUrl: null,
);

const _names = {'tv-a': '메인 TV', 'tv-b': '창가 TV', 'tv-c': '입구 TV'};

List<OperationEvent> _events(OperationEventRange range) {
  OperationEvent event(
    String id,
    String type,
    int seconds, {
    String device = 'tv-a',
    String? incident,
    String? recovery,
    String? errorId,
    String? errorCode,
    String? phase,
  }) => OperationEvent(
    id: id,
    eventId: id,
    type: type,
    occurredAtMs: range.startAtMs + seconds * 1000,
    deviceId: device,
    deviceName: _names[device] ?? '코치 휴대폰',
    zoneName: device == 'phone' ? null : '1층 트레이닝실',
    deviceRole: device == 'phone' ? 'controller' : 'display',
    appVersion: '1.1.1+69',
    phase: phase ?? 'server_connection',
    workoutId: 'strength',
    workoutName: '전신 근력 서킷',
    sessionId: 'class-morning',
    scheduled: false,
    scheduledAtMs: null,
    schemaVersion: 2,
    incidentId: incident,
    recoveryOfEventId: recovery,
    errorId: errorId,
    errorCode: errorCode,
    targetDeviceIds: device == 'phone' ? _names.keys.toList() : const [],
    targetDeviceNames: device == 'phone' ? _names : const {},
    targetDeviceVersions: device == 'phone'
        ? {for (final id in _names.keys) id: '1.1.1+69'}
        : const {},
  );
  return [
    for (final id in _names.keys)
      event('$id-online', 'device_online', 1, device: id),
    event(
      'class-start',
      'playback_started',
      20,
      device: 'phone',
      phase: 'server_approval',
    ),
    event(
      'server-approved',
      'command_approved',
      35,
      device: 'phone',
      phase: 'server_approval',
    ),
    for (final id in _names.keys)
      event(
        '$id-received',
        'command_received',
        36,
        device: id,
        phase: 'tv_receipt',
      ),
    event(
      'disconnect',
      'device_offline',
      90,
      device: 'tv-b',
      incident: 'connection-1',
    ),
    event(
      'controller-failure',
      'command_failed',
      100,
      device: 'phone',
      phase: 'server_approval',
      errorId: 'support-error-001',
      errorCode: 'request_timeout',
    ),
    event(
      'reconnected',
      'device_online',
      120,
      device: 'tv-b',
      incident: 'connection-1',
      recovery: 'disconnect',
    ),
  ];
}

class _Workouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value(const []);
}

class _News extends UpdateNewsController {
  @override
  Future<UpdateNewsState> build() async => const UpdateNewsState(
    notes: [
      UpdateNews(
        id: 'capture-update',
        title: '더 편해진 수업 준비',
        summary: '업데이트된 수업과 센터 관리 기능을 만나보세요.',
        date: '2026-10-14',
        version: '1.1.1',
        builds: {'web': '69'},
        items: [],
      ),
    ],
  );
}

void main() {
  for (final (name, size) in [
    ('mobile320', const Size(320, 568)),
    ('mobile390', const Size(390, 844)),
    ('web1280', const Size(1280, 900)),
  ]) {
    testWidgets('capture report, detail, and More at $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fonts = FontLoader('Pretendard');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        fonts.addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
        );
      }
      await fonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final boundary = GlobalKey();
      final router = GoRouter(
        initialLocation: '/operations',
        routes: [
          GoRoute(
            path: '/operations',
            builder: (_, _) => const StoreOperationsScreen(),
          ),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
          GoRoute(
            path: '/support',
            builder: (_, _) => const Scaffold(body: Text('문의 작성')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authStateProvider.overrideWith((_) => Stream.value(_owner)),
            planAccessProvider.overrideWith((_) => Stream.value(null)),
            accountWorkoutPreferencesProvider.overrideWith(
              (_, _) async => const WorkoutPreferences(),
            ),
            brandTemplateProvider.overrideWith(
              (_) => Stream.value(BrandTemplate.initial()),
            ),
            workoutSchedulesProvider.overrideWith(
              (_) => Stream.value(const []),
            ),
            operationEventsProvider.overrideWith((_) => Stream.value(const [])),
            operationEventsInRangeProvider.overrideWith(
              (_, range) => Stream.value(
                OperationEventBatch(events: _events(range), isComplete: true),
              ),
            ),
            displayDevicesProvider.overrideWith((_) => Stream.value(const [])),
            workoutControllerProvider.overrideWith(_Workouts.new),
            fixtureWorkoutDetails,
            updateNewsControllerProvider.overrideWith(_News.new),
          ],
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: XonTheme.responsiveBuilder,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String scene) async {
        expect(tester.takeException(), isNull, reason: '$name/$scene');
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/sta174-capture')
            ..createSync(recursive: true);
          await File('${directory.path}/$name-$scene.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final reportScroller = find
          .descendant(
            of: find.byType(OperationsReportTab),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.tap(find.text('리포트'));
      await tester.pumpAndSettle();
      await capture('report-top');
      await tester.scrollUntilVisible(
        find.text('선택 기간 요약'),
        200,
        scrollable: reportScroller,
      );
      await tester.pumpAndSettle();
      await capture('report-summary');
      final row = find.byKey(const ValueKey('operation-event-disconnect'));
      await tester.scrollUntilVisible(row, 260, scrollable: reportScroller);
      await tester.pumpAndSettle();
      await capture('report-records');
      await tester.tap(row);
      await tester.pumpAndSettle();
      await capture('detail-recovered-top');
      await tester.scrollUntilVisible(
        find.text('이 기록으로 문의하기'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('operation-event-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await capture('detail-recovered-bottom');
      router.pop();
      await tester.pumpAndSettle();
      final failure = find.byKey(
        const ValueKey('operation-event-controller-failure'),
      );
      await tester.scrollUntilVisible(
        failure,
        -220,
        scrollable: reportScroller,
      );
      await tester.tap(failure);
      await tester.pumpAndSettle();
      await capture('detail-controller-failure');
      router.pop();
      router.go('/more');
      await tester.pumpAndSettle();
      await capture('more-top');
      await tester.scrollUntilVisible(
        find.text('업데이트 소식'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await capture('more-bottom');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
