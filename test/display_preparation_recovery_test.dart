import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/hooks/use_display_preparation.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

DisplayPreparation _candidate({
  String session = 'candidate',
  bool expired = false,
}) => DisplayPreparation(
  sessionId: session,
  revision: 1,
  manifestHash: session,
  workoutId: 'workout',
  expiresAtMs: DateTime.now().millisecondsSinceEpoch + (expired ? -1 : 90000),
  targetDeviceIds: const ['tv'],
  images: const [],
  sounds: const [],
  requiredProtocol: 1,
);

class _Diagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

class _Repository implements DisplayPreparationRepository {
  DisplayPreparation? candidate = _candidate();
  Object? requestError, streamError, receiptError, responseError;
  Completer<void>? responseGate;
  Stream<DisplayPreparation?> Function()? requestStream;
  int subscriptions = 0;
  final responses = <String>[];
  @override
  Stream<DisplayPreparation?> watchRequest(String deviceId) {
    subscriptions++;
    if (requestStream != null) return requestStream!();
    return streamError == null
        ? Stream.value(candidate)
        : Stream.error(streamError!);
  }

  @override
  Future<void> request(DisplayPreparation request) async {
    if (requestError != null) throw requestError!;
    candidate = request;
  }

  @override
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() =>
      receiptError == null ? Stream.value({}) : Stream.error(receiptError!);
  @override
  Future<void> respond(
    String deviceId,
    DisplayPreparation request, {
    required bool ready,
    required int imageCount,
    required bool audioReady,
  }) async {
    responses.add(request.sessionId);
    await responseGate?.future;
    if (responseError != null) throw responseError!;
    expect(ready, isTrue);
    expect(imageCount, 0);
    expect(audioReady, isTrue);
  }

  @override
  Future<void> heartbeat(String deviceId, {bool ready = false}) async {}
  @override
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
  }) async {}
  @override
  Future<void> cancel(String sessionId) async {}
  @override
  Future<DisplayPreparation?> current() async => candidate;
  @override
  Future<Map<String, DisplayPreparationReceipt>> receipts() =>
      watchReceipts().first;
}

class _Harness extends HookConsumerWidget {
  const _Harness({
    required this.connected,
    this.paired = true,
    this.foreground = true,
  });
  final bool connected, paired, foreground;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useDisplayPreparation(
      context,
      ref,
      deviceId: 'tv',
      paired: paired,
      standby: true,
      connected: connected,
      foreground: foreground,
    );
    return const SizedBox();
  }
}

class _Fixture {
  final repository = _Repository();
  final diagnostics = _Diagnostics();
  final events = <Map<String, dynamic>>[];
  late final telemetry = OperationTelemetry(
    readAccount: () => 'display',
    emit: (event, _) async => events.add(event),
  );
  late final container = ProviderContainer(
    overrides: [
      displayPreparationRepositoryProvider.overrideWithValue(repository),
      serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
      errorReporterProvider.overrideWithValue(ErrorReporter(diagnostics)),
      operationTelemetryProvider.overrideWithValue(telemetry),
    ],
  );
  Future<void> mount(
    WidgetTester tester, {
    bool connected = true,
    bool paired = true,
    bool foreground = true,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: _Harness(
            connected: connected,
            paired: paired,
            foreground: foreground,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await telemetry.flush();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }
}

void main() {
  testWidgets(
    'stream error cancels cached candidate work; fresh subscription can prepare the same candidate',
    (tester) async {
      final f = _Fixture();
      final stream = StreamController<DisplayPreparation?>();
      f.repository.requestStream = () => stream.stream;
      f.repository.responseGate = Completer<void>();
      await f.mount(tester);
      stream.add(f.repository.candidate);
      await tester.pumpAndSettle();
      expect(f.repository.responses, ['candidate']);
      stream.addError(StateError('connection denied'));
      await tester.pumpAndSettle();
      f.repository.responseGate!.complete();
      await tester.pumpAndSettle();
      await f.telemetry.flush();
      expect(
        f.events.where((e) => e['action'] == 'tv.prepare').last['outcome'],
        'cancelled',
      );
      f.repository.requestStream = null;
      f.repository.responseGate = null;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      await f.telemetry.flush();
      expect(f.repository.responses, ['candidate', 'candidate']);
      expect(f.events.last['outcome'], 'success');
      await f.close(tester);
      unawaited(stream.close());
    },
  );

  testWidgets(
    'response timeout records the response stage without a false success',
    (tester) async {
      final f = _Fixture();
      f.repository.responseGate = Completer<void>();
      await f.mount(tester);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      await f.telemetry.flush();
      expect(f.events.any((e) => e['outcome'] == 'success'), isFalse);
      expect(f.diagnostics.events.first.error, isA<TimeoutException>());
      expect(
        f.diagnostics.events.first.context['preparationStage'],
        'response',
      );
      for (final backoff in [1, 2, 4]) {
        await tester.pump(Duration(seconds: backoff));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      }
      await f.telemetry.flush();
      expect(f.repository.responses, hasLength(4));
      expect(f.events.last['code'], 'prepare_response');
      f.repository.responseGate!.complete();
      await tester.pump();
      await f.telemetry.flush();
      expect(f.events.any((e) => e['outcome'] == 'success'), isFalse);
      await f.close(tester);
    },
  );

  testWidgets(
    'TV success requires confirmed response write; permission failure keeps original diagnostics',
    (tester) async {
      final f = _Fixture();
      f.repository.responseGate = Completer<void>();
      final error = FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
        message: 'private database path',
      );
      await f.mount(tester);
      expect(f.repository.responses, ['candidate']);
      expect(f.events.map((e) => e['outcome']), ['attempt']);
      f.repository.responseError = error;
      f.repository.responseGate!.complete();
      await tester.pumpAndSettle();
      await f.telemetry.flush();
      expect(f.events.map((e) => e['outcome']), ['attempt', 'failure']);
      expect(f.events.last['code'], 'prepare_response');
      expect(f.diagnostics.events.single.error, same(error));
      expect(
        f.diagnostics.events.single.context['preparationStage'],
        'response',
      );
      expect(
        f.diagnostics.events.single.context['firebaseCode'],
        'permission-denied',
      );
      expect(f.diagnostics.events.single.stack.toString(), isNotEmpty);
      await f.close(tester);
    },
  );

  testWidgets(
    'failed response retries after reconnect and only then records success',
    (tester) async {
      final f = _Fixture();
      f.repository.responseError = FirebaseException(
        plugin: 'firebase_database',
        code: 'unavailable',
      );
      await f.mount(tester);
      for (final backoff in [1, 2, 4]) {
        await tester.pump(Duration(seconds: backoff));
        await tester.pumpAndSettle();
      }
      await f.telemetry.flush();
      expect(f.events.last['code'], 'prepare_response');
      await f.mount(tester, connected: false);
      f.repository.responseError = null;
      await f.mount(tester);
      expect(f.repository.responses, List.filled(5, 'candidate'));
      expect(f.events.map((e) => e['outcome']), [
        'attempt',
        'failure',
        'attempt',
        'success',
      ]);
      await f.close(tester);
    },
  );

  for (final reconnect in [false, true]) {
    testWidgets(
      'terminated request subscription recovers on ${reconnect ? 'reconnect' : 'bounded retry'}',
      (tester) async {
        final f = _Fixture();
        final error = FirebaseException(
          plugin: 'firebase_database',
          code: reconnect ? 'permission-denied' : 'unavailable',
        );
        f.repository.streamError = error;
        await f.mount(tester);
        expect(f.repository.responses, isEmpty);
        expect(f.diagnostics.events.single.error, same(error));
        expect(f.events.any((e) => e['code'] == 'prepare_listen'), isTrue);
        if (reconnect) await f.mount(tester, connected: false);
        f.repository.streamError = null;
        if (reconnect) {
          await f.mount(tester);
        } else {
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          await f.telemetry.flush();
        }
        expect(f.repository.subscriptions, greaterThanOrEqualTo(2));
        expect(f.repository.responses, ['candidate']);
        expect(f.events.last['outcome'], 'success');
        await f.close(tester);
      },
    );
  }

  testWidgets(
    'permission denial stops request retries until a foreground scope restart',
    (tester) async {
      final f = _Fixture();
      f.repository.streamError = FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      );
      await f.mount(tester);
      expect(f.repository.subscriptions, 1);
      f.repository.streamError = null;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(f.repository.subscriptions, 1);
      expect(f.repository.responses, isEmpty);
      await f.mount(tester, foreground: false);
      await f.mount(tester);
      expect(f.repository.subscriptions, 2);
      expect(f.repository.responses, ['candidate']);
      await f.close(tester);
    },
  );

  testWidgets(
    'request transport retry budget remains exhausted until a new connection scope',
    (tester) async {
      final f = _Fixture();
      f.repository.streamError = FirebaseException(
        plugin: 'firebase_database',
        code: 'unavailable',
      );
      await f.mount(tester);
      for (final backoff in [1, 2, 4]) {
        await tester.pump(Duration(seconds: backoff));
        await tester.pumpAndSettle();
      }
      expect(f.repository.subscriptions, 4);
      f.repository.streamError = null;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(f.repository.subscriptions, 4);
      expect(f.repository.responses, isEmpty);
      await f.mount(tester, connected: false);
      await f.mount(tester);
      expect(f.repository.subscriptions, 5);
      expect(f.repository.responses, ['candidate']);
      await f.close(tester);
    },
  );

  testWidgets(
    'pairing recovery must finish before request stream or ACK starts',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester, paired: false);
      expect(f.repository.subscriptions, 0);
      expect(f.repository.responses, isEmpty);
      await f.mount(tester);
      expect(f.repository.subscriptions, 1);
      expect(f.repository.responses, ['candidate']);
      await f.close(tester);
    },
  );

  testWidgets(
    'expired candidate never responds, disposal of an in-flight response cannot report success',
    (tester) async {
      final f = _Fixture();
      f.repository.candidate = _candidate(expired: true);
      await f.mount(tester);
      expect(f.repository.responses, isEmpty);
      f.repository.candidate = _candidate(session: 'current');
      f.repository.responseGate = Completer<void>();
      f.container.invalidate(displayPreparationRequestProvider('tv'));
      await tester.pumpAndSettle();
      expect(f.repository.responses, ['current']);
      await tester.pumpWidget(const SizedBox());
      f.repository.responseGate!.complete();
      await tester.pump();
      await f.telemetry.flush();
      expect(f.events.last['outcome'], 'cancelled');
      expect(f.events.any((e) => e['outcome'] == 'success'), isFalse);
      f.container.dispose();
    },
  );

  test('owner request and receipt failures stay distinct and retry creates a new candidate', () async {
    final f = _Fixture();
    final subscription = f.container.listen(
      displayPreparationControllerProvider,
      (_, _) {},
    );
    final controller = f.container.read(
      displayPreparationControllerProvider.notifier,
    );
    final workout = Workout.empty(
      'workout',
      const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
    );
    final requestError = FirebaseException(
      plugin: 'firebase_database',
      code: 'permission-denied',
    );
    f.repository.requestError = requestError;
    await controller.prepare(workout, ['tv']);
    expect(
      f.container.read(displayPreparationControllerProvider).error,
      contains('요청을 보내지 못했어요'),
    );
    expect(f.diagnostics.events.single.error, same(requestError));
    f.repository.requestError = null;
    f.repository.receiptError = StateError('private receipt stream error');
    await controller.prepare(workout, ['tv']);
    await Future<void>.delayed(Duration.zero);
    final failed = f.container.read(displayPreparationControllerProvider);
    expect(failed.error, contains('응답을 확인하지 못했어요'));
    expect(failed.error, isNot(contains('private')));
    expect(f.diagnostics.events.last.context['preparationStage'], 'receipts');
    f.repository.receiptError = null;
    await controller.prepare(workout, ['tv']);
    await Future<void>.delayed(Duration.zero);
    final ready = f.container.read(displayPreparationControllerProvider);
    expect(ready.error, isNull);
    expect(ready.request!.sessionId, isNot(failed.request!.sessionId));
    await f.telemetry.flush();
    expect(
      f.events.where((e) => e['outcome'] == 'failure').map((e) => e['code']),
      ['prepare_request', 'prepare_receipts'],
    );
    subscription.close();
    f.container.dispose();
  });
}
