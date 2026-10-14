import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/device/presentation/hooks/use_display_recovery.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/display_recovery_data_source.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_recovery_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_recovery_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/execute_display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_recovery_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

DisplayRecoveryRequest request({
  String id = 'op',
  DisplayRecoveryStatus status = DisplayRecoveryStatus.requested,
  int? now,
}) {
  final time = now ?? DateTime.now().millisecondsSinceEpoch;
  return DisplayRecoveryRequest(
    operationId: id,
    deviceId: 'tv',
    status: status,
    requestedAtMs: time,
    expiresAtMs: time + 60000,
  );
}

const tv = DisplayDevice(
  id: 'tv',
  name: 'TV',
  zoneId: 'main',
  zoneName: 'main',
  online: true,
  lastSeenAtMs: 1,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
);

class FakeRecovery implements DisplayRecoveryRepository {
  final stream = StreamController<DisplayRecoveryRequest?>.broadcast();
  final reports = <DisplayRecoveryStatus>[];
  Completer<DisplayRecoveryRequest>? pending;
  int requests = 0;
  String? operationId;
  @override
  Stream<DisplayRecoveryRequest?> watch(String deviceId) => stream.stream;
  @override
  Future<DisplayRecoveryRequest> request(String deviceId, String operationId) {
    requests++;
    this.operationId = operationId;
    return (pending ??= Completer<DisplayRecoveryRequest>()).future;
  }

  @override
  Future<void> report(
    DisplayRecoveryRequest request,
    DisplayRecoveryStatus status, {
    String? sessionId,
    int? revision,
    String? errorCode,
  }) async {
    reports.add(status);
  }
}

void main() {
  test('decode server operation and reject malformed status', () {
    final value = decodeDisplayRecovery({
      'operationId': 'op',
      'deviceId': 'tv',
      'status': 'received',
      'requestedAtMs': 100,
      'expiresAtMs': 200,
    });
    expect(value!.pending, isTrue);
    expect(value.expired(199), isFalse);
    expect(value.expire().status, DisplayRecoveryStatus.expired);
    expect(
      () => decodeDisplayRecovery({'status': 'success'}),
      throwsFormatException,
    );
  });

  test('TV acknowledges received/recovering before verified success', () async {
    final repository = FakeRecovery();
    await executeDisplayRecovery(
      request: request(now: 100),
      actions: DisplayRecoveryActions(repository),
      cancelled: () => false,
      now: () => 101,
      recover: () async {
        expect(repository.reports, [
          DisplayRecoveryStatus.received,
          DisplayRecoveryStatus.recovering,
        ]);
        return true;
      },
      currentSession: () => (sessionId: 'session', revision: 3),
    );
    expect(repository.reports.last, DisplayRecoveryStatus.succeeded);
    unawaited(repository.stream.close());
  });

  test('failed local recovery never reports success', () async {
    final repository = FakeRecovery();
    await executeDisplayRecovery(
      request: request(now: 100),
      actions: DisplayRecoveryActions(repository),
      cancelled: () => false,
      now: () => 101,
      recover: () async => false,
      currentSession: () => (sessionId: 'session', revision: 3),
    );
    expect(repository.reports, [
      DisplayRecoveryStatus.received,
      DisplayRecoveryStatus.recovering,
      DisplayRecoveryStatus.failed,
    ]);
    unawaited(repository.stream.close());
  });

  test('account cancellation and expiration fence late completion', () async {
    for (final expire in [false, true]) {
      final repository = FakeRecovery();
      final recovery = Completer<bool>();
      var cancelled = false;
      var now = 101;
      final flight = executeDisplayRecovery(
        request: request(now: 100),
        actions: DisplayRecoveryActions(repository),
        cancelled: () => cancelled,
        now: () => now,
        recover: () => recovery.future,
        currentSession: () => (sessionId: 'session', revision: 3),
      );
      await Future<void>.delayed(Duration.zero);
      if (expire) {
        now = 60100;
      } else {
        cancelled = true;
      }
      recovery.complete(true);
      await flight;
      expect(repository.reports, [
        DisplayRecoveryStatus.received,
        DisplayRecoveryStatus.recovering,
      ]);
      unawaited(repository.stream.close());
    }
  });

  testWidgets(
    'controller singleflight and stream progress cannot regress on late response',
    (tester) async {
      final repository = FakeRecovery();
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          displayRecoveryRepositoryProvider.overrideWithValue(repository),
          displayDevicesProvider.overrideWith((ref) => Stream.value([tv])),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        ],
      );
      final sub = container.listen(
        displayRecoveryControllerProvider('tv'),
        (_, _) {},
      );
      await tester.pump();
      repository.stream.add(null);
      await tester.pump();
      final notifier = container.read(
        displayRecoveryControllerProvider('tv').notifier,
      );
      final pending = notifier.request();
      expect(await notifier.request(), isFalse);
      expect(repository.requests, 1);
      final accepted = request(
        id: repository.operationId!,
        status: DisplayRecoveryStatus.recovering,
      );
      repository.stream.add(accepted);
      await tester.pump();
      repository.pending!.complete(
        request(id: accepted.operationId, now: accepted.requestedAtMs),
      );
      expect(await pending, isTrue);
      expect(
        container.read(displayRecoveryControllerProvider('tv')).value!.status,
        DisplayRecoveryStatus.recovering,
      );
      sub.close();
      container.dispose();
      unawaited(repository.stream.close());
    },
  );

  testWidgets(
    'owner change clears old request and ignores in-flight completion',
    (tester) async {
      final owner = StreamController<String?>();
      final repository = FakeRecovery();
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => owner.stream),
          displayRecoveryRepositoryProvider.overrideWithValue(repository),
          displayDevicesProvider.overrideWith((ref) => Stream.value([tv])),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        ],
      );
      final sub = container.listen(
        displayRecoveryControllerProvider('tv'),
        (_, _) {},
      );
      owner.add('owner');
      await tester.pump();
      repository.stream.add(null);
      await tester.pump();
      final pending = container
          .read(displayRecoveryControllerProvider('tv').notifier)
          .request();
      owner.add(null);
      await tester.pump();
      repository.pending!.complete(request(id: repository.operationId!));
      expect(await pending, isFalse);
      expect(
        container.read(displayRecoveryControllerProvider('tv')).value,
        isNull,
      );
      sub.close();
      container.dispose();
      unawaited(owner.close());
      unawaited(repository.stream.close());
    },
  );

  testWidgets('missing acknowledgement expires using server-adjusted time', (
    tester,
  ) async {
    final repository = FakeRecovery();
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
        displayRecoveryRepositoryProvider.overrideWithValue(repository),
        displayDevicesProvider.overrideWith((ref) => Stream.value([tv])),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(100000)),
      ],
    );
    final sub = container.listen(
      displayRecoveryControllerProvider('tv'),
      (_, _) {},
    );
    await tester.pump();
    await tester.pump();
    container.read(displayRecoveryControllerProvider('tv'));
    expect(repository.stream.hasListener, isTrue);
    repository.stream.add(request());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final state = container.read(displayRecoveryControllerProvider('tv'));
    expect(state.hasError, isFalse, reason: state.toString());
    expect(
      state.value?.status,
      DisplayRecoveryStatus.expired,
      reason: state.toString(),
    );
    sub.close();
    container.dispose();
    unawaited(repository.stream.close());
  });

  testWidgets('initial silent stream becomes retryable error', (tester) async {
    final repository = FakeRecovery();
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
        displayRecoveryRepositoryProvider.overrideWithValue(repository),
        displayDevicesProvider.overrideWith((ref) => Stream.value([tv])),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
      ],
    );
    final sub = container.listen(
      displayRecoveryControllerProvider('tv'),
      (_, _) {},
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(
      container.read(displayRecoveryControllerProvider('tv')).hasError,
      isTrue,
    );
    sub.close();
    container.dispose();
    unawaited(repository.stream.close());
  });
  testWidgets('response loss keeps the unresolved callable single-flight', (
    tester,
  ) async {
    final repository = FakeRecovery();
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
        displayRecoveryRepositoryProvider.overrideWithValue(repository),
        displayDevicesProvider.overrideWith((ref) => Stream.value([tv])),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
      ],
    );
    final sub = container.listen(
      displayRecoveryControllerProvider('tv'),
      (_, _) {},
    );
    await tester.pump();
    final notifier = container.read(
      displayRecoveryControllerProvider('tv').notifier,
    );
    final pending = notifier.request();
    await tester.pump(const Duration(seconds: 17));
    expect(await pending, isFalse);
    expect(await notifier.request(), isFalse);
    expect(repository.requests, 1);
    repository.pending!.complete(request(id: repository.operationId!));
    await tester.pump();
    sub.close();
    container.dispose();
    unawaited(repository.stream.close());
  });

  testWidgets('a delayed old response cannot replace a newer operation', (
    tester,
  ) async {
    final repository = FakeRecovery();
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
        displayRecoveryRepositoryProvider.overrideWithValue(repository),
        displayDevicesProvider.overrideWith((ref) => Stream.value([tv])),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
      ],
    );
    final sub = container.listen(
      displayRecoveryControllerProvider('tv'),
      (_, _) {},
    );
    await tester.pump();
    final notifier = container.read(
      displayRecoveryControllerProvider('tv').notifier,
    );
    final pending = notifier.request();
    final old = request(id: repository.operationId!);
    final newer = request(id: 'newer-op', now: old.requestedAtMs + 1);
    repository.stream.add(newer);
    await tester.pump();
    repository.pending!.complete(old);
    await pending;
    expect(
      container
          .read(displayRecoveryControllerProvider('tv'))
          .value!
          .operationId,
      'newer-op',
    );
    sub.close();
    container.dispose();
    unawaited(repository.stream.close());
  });
  for (final code in ['permission-denied', 'unauthenticated']) {
    testWidgets('$code never automatically retries a TV recovery listener', (
      tester,
    ) async {
      final repository = RetryRecovery(code);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
            displayRecoveryRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: RecoveryHookProbe(connected: true)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 1);
      await tester.pump(const Duration(seconds: 40));
      expect(repository.calls, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('network listener retries only after 1, 2 and 4 seconds', (
    tester,
  ) async {
    final repository = RetryRecovery('unavailable');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          displayRecoveryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: RecoveryHookProbe(connected: true)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(repository.calls, 1);
    await tester.pump(const Duration(milliseconds: 999));
    expect(repository.calls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.calls, 2);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(repository.calls, 3);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(repository.calls, 4);
    await tester.pump(const Duration(seconds: 40));
    expect(repository.calls, 4);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reconnect and foreground resume safely restart a denied listener',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final repository = RetryRecovery('permission-denied');
      final connected = ValueNotifier(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
            displayRecoveryRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder(
              valueListenable: connected,
              builder: (_, value, _) => RecoveryHookProbe(connected: value),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 1);
      connected.value = false;
      await tester.pump();
      await tester.pump();
      connected.value = true;
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(repository.calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 3);
      await tester.pumpWidget(const SizedBox());
      connected.dispose();
    },
  );
  testWidgets('background cancels a pending network retry until resume', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = RetryRecovery('unavailable');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          displayRecoveryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: RecoveryHookProbe(connected: true)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(repository.calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(repository.calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(repository.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
}

class RetryRecovery extends Fake implements DisplayRecoveryRepository {
  RetryRecovery(this.code);
  final String code;
  int calls = 0;
  @override
  Stream<DisplayRecoveryRequest?> watch(String deviceId) {
    calls++;
    return Stream.error(FirebaseException(plugin: 'database', code: code));
  }
}

class RecoveryHookProbe extends HookConsumerWidget {
  const RecoveryHookProbe({super.key, required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useDisplayRecovery(
      context,
      ref,
      deviceId: 'tv',
      paired: true,
      connected: connected,
    );
    return const SizedBox();
  }
}
