import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_recovery_repository.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_recovery_dialog.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

import 'support/management_journey_fixture.dart';

void main() {
  Future<_Fixture> mount(
    WidgetTester tester, {
    bool online = true,
    Size size = const Size(390, 844),
    double scale = 1,
    Widget? page,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _Fixture(online: online);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
    await tester.pumpWidget(
      fixture.scope(
        MaterialApp(
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home:
              page ??
              const Scaffold(
                body: DisplayRecoveryDialog(deviceId: 'tv-a', ownerId: 'owner'),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  testWidgets(
    'per-display menu opens only its recovery and silent stale heartbeat updates the list count',
    (tester) async {
      final fixture = await mount(
        tester,
        page: const DisplaySettingsScreen(asMainTab: true),
      );
      expect(find.text('등록 1대 · 온라인 1대'), findsOneWidget);
      fixture.clock.add(DateTime.now().millisecondsSinceEpoch + 76000);
      await tester.pumpAndSettle();
      expect(find.text('등록 1대 · 온라인 0대'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('연결 복구'));
      await tester.pumpAndSettle();
      expect(find.byType(DisplayRecoveryDialog), findsOneWidget);
      expect(find.text('서버 응답 · 최근 응답 없음'), findsOneWidget);
      await tester.tap(find.text('연결 복구 시작'));
      await tester.pumpAndSettle();
      expect(fixture.repository.requestedDeviceIds, ['tv-a']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline request never means success and repeated taps send one operation',
    (tester) async {
      final fixture = await mount(tester, online: false);
      expect(find.textContaining('전원이 꺼져 있거나 인터넷이 없는 TV'), findsOneWidget);
      await tester.tap(find.text('연결 복구 시작'));
      await tester.pumpAndSettle();
      expect(fixture.repository.requests, 1);
      expect(find.textContaining('연결 복구가 확인되었습니다'), findsNothing);
      expect(find.text('복구 확인 중…'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      fixture.repository.emit(DisplayRecoveryStatus.received);
      await tester.pumpAndSettle();
      expect(find.textContaining('연결 복구가 확인되었습니다'), findsNothing);
      fixture.repository.emit(DisplayRecoveryStatus.recovering);
      await tester.pumpAndSettle();
      expect(find.textContaining('연결 복구가 확인되었습니다'), findsNothing);
      fixture.repository.emit(DisplayRecoveryStatus.succeeded);
      await tester.pumpAndSettle();
      expect(find.textContaining('연결 복구가 확인되었습니다'), findsOneWidget);
      expect(find.text('다시 확인').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'expired and denied recovery explain field actions without raw exception data',
    (tester) async {
      final fixture = await mount(tester);
      fixture.repository.failure = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'private/path/token-do-not-show',
        details: {'code': 'connection_conflict'},
      );
      await tester.tap(find.text('연결 복구 시작'));
      await tester.pumpAndSettle();
      expect(find.textContaining('연결 정보가 서로 일치하지 않습니다'), findsOneWidget);
      expect(find.textContaining('token-do-not-show'), findsNothing);
      fixture.repository.failure = null;
      fixture.repository.emit(DisplayRecoveryStatus.expired);
      await tester.pumpAndSettle();
      expect(find.textContaining('제한시간 안에 TV 복구 응답을 받지 못했습니다'), findsOneWidget);
      expect(find.textContaining('연결 복구가 확인되었습니다'), findsNothing);
    },
  );

  testWidgets(
    'an account switch hides identity and ignores a delayed old-owner response',
    (tester) async {
      final fixture = await mount(tester);
      fixture.repository.pending = Completer<DisplayRecoveryRequest>();
      await tester.tap(find.text('연결 복구 시작'));
      await tester.pump();
      fixture.owners.add('different-owner');
      await tester.pumpAndSettle();
      expect(find.text('오른쪽 TV'), findsNothing);
      expect(find.textContaining('매장 계정이 변경되었습니다'), findsOneWidget);
      fixture.repository.pending!.complete(
        fixture.repository.value(DisplayRecoveryStatus.succeeded),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('연결 복구가 확인되었습니다'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unpaired device cannot retain a recovery action or success', (
    tester,
  ) async {
    final fixture = await mount(tester);
    fixture.devices.add([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('이 TV의 연결이 해제되었습니다'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('오른쪽 TV'), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(1280, 900)]) {
    testWidgets('recovery controls remain reachable at $size and double text', (
      tester,
    ) async {
      final fixture = await mount(tester, size: size, scale: 2);
      expect(find.text('연결 복구 시작').hitTestable(), findsOneWidget);
      expect(find.text('닫기').hitTestable(), findsOneWidget);
      await tester.tap(find.text('연결 복구 시작'));
      await tester.pumpAndSettle();
      fixture.repository.emit(
        DisplayRecoveryStatus.failed,
        errorCode: 'permission_denied',
      );
      await tester.pumpAndSettle();
      expect(find.text('다시 확인').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _Fixture {
  _Fixture({required bool online}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tv = DisplayDevice(
      id: 'tv-a',
      name: '오른쪽 TV',
      zoneId: 'main',
      zoneName: '메인 구역',
      online: online,
      lastSeenAtMs: online ? now : 0,
      currentSessionId: null,
      acknowledgedRevision: 0,
      paired: true,
      recoveryProtocol: 1,
    );
    scope = (child) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        accountOwnerIdProvider.overrideWith(
          (_) => _withInitial('owner', owners.stream),
        ),
        displayDevicesProvider.overrideWith(
          (_) => _withInitial([tv], devices.stream),
        ),
        displayHealthNowProvider.overrideWith(
          (_) => _withInitial(now, clock.stream),
        ),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        displayRecoveryRepositoryProvider.overrideWithValue(repository),
        androidTvProvider.overrideWith((_) async => false),
        deviceModeControllerProvider.overrideWith(ManagementMode.new),
        deviceClaimControllerProvider.overrideWith(ManagementClaims.new),
        userProfileControllerProvider.overrideWith(
          () => ManagementProfiles(managementProfile),
        ),
      ],
      child: Consumer(
        builder: (_, ref, _) {
          ref.watch(accountOwnerIdProvider);
          return child;
        },
      ),
    );
  }
  final repository = _RecoveryRepository();
  final owners = StreamController<String?>.broadcast();
  final devices = StreamController<List<DisplayDevice>>.broadcast();
  final clock = StreamController<int>.broadcast();
  late final Widget Function(Widget) scope;
  void dispose() {
    unawaited(owners.close());
    unawaited(devices.close());
    unawaited(clock.close());
    unawaited(repository.events.close());
  }
}

Stream<T> _withInitial<T>(T initial, Stream<T> changes) async* {
  yield initial;
  yield* changes;
}

class _RecoveryRepository implements DisplayRecoveryRepository {
  int requests = 0;
  final requestedDeviceIds = <String>[];
  Object? failure;
  Completer<DisplayRecoveryRequest>? pending;
  final events = StreamController<DisplayRecoveryRequest?>.broadcast();
  String operationId = 'operation-fixture';
  DisplayRecoveryRequest value(
    DisplayRecoveryStatus status, {
    String? errorCode,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DisplayRecoveryRequest(
      operationId: operationId,
      deviceId: 'tv-a',
      status: status,
      requestedAtMs: now,
      expiresAtMs: now + 60000,
      errorCode: errorCode,
    );
  }

  void emit(DisplayRecoveryStatus status, {String? errorCode}) =>
      events.add(value(status, errorCode: errorCode));
  @override
  Stream<DisplayRecoveryRequest?> watch(String deviceId) =>
      _withInitial(null, events.stream);
  @override
  Future<DisplayRecoveryRequest> request(String deviceId, String id) async {
    requests++;
    operationId = id;
    requestedDeviceIds.add(deviceId);
    if (failure != null) throw failure!;
    return pending?.future ?? value(DisplayRecoveryStatus.requested);
  }

  @override
  Future<void> report(
    DisplayRecoveryRequest request,
    DisplayRecoveryStatus status, {
    String? sessionId,
    int? revision,
    String? errorCode,
  }) async {}
}
