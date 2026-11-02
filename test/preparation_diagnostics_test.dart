import 'dart:async';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/core/observability/preparation_diagnostics.dart';
import 'package:cloud_board/src/app/core/observability/preparation_probe.dart';
import 'package:cloud_board/src/app/core/observability/preparation_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final lateError in [false, true]) {
    testWidgets(
      'timeout preserves late ${lateError ? 'failure' : 'success'} without changing the original outcome',
      (tester) async {
        final events = <Map<String, dynamic>>[];
        var time = 0, id = 0;
        final telemetry = OperationTelemetry(
          readAccount: () => 'owner',
          createId: () => (++id).toRadixString(16).padLeft(32, '0'),
          emit: (e, _) async => events.add(e),
        );
        final diagnostics = PreparationDiagnostics(elapsedMs: () => time);
        final write = Completer<void>();
        final attempt = telemetry.start(
          'tv.prepare.request',
          trace: {'requestId': 'prepare-test-1'},
        );
        Object? failure;
        unawaited(
          diagnostics
              .observeRequest(
                write: () => write.future,
                attempt: attempt,
                requestId: 'prepare-test-1',
                superseded: () => true,
              )
              .then(
                (_) => attempt.success(),
                onError: (Object e) {
                  failure = e;
                  attempt.failure(e);
                },
              ),
        );
        expect(diagnostics.snapshot()['pendingWrites'], 1);
        time = 8000;
        await tester.pump(const Duration(seconds: 8));
        expect(failure, isA<TimeoutException>());
        expect(diagnostics.snapshot()['pendingWrites'], 1);
        time = 11000;
        if (lateError) {
          write.completeError(StateError('late'));
        } else {
          write.complete();
        }
        await tester.pump();
        await telemetry.flush();
        expect(diagnostics.snapshot()['pendingWrites'], 0);
        final terminal = events
            .where((e) => e['outcome'] != 'attempt')
            .toList();
        expect(terminal.map((e) => e['action']), [
          'tv.prepare.request',
          'tv.prepare.settlement',
        ]);
        expect(terminal.first['outcome'], 'failure');
        expect(terminal.last['outcome'], lateError ? 'failure' : 'success');
        expect(
          terminal.last['trace'],
          containsPair('parentOperationId', attempt.id),
        );
        expect(terminal.last['trace'], containsPair('writeElapsedMs', 11000));
        expect(terminal.last['trace'], containsPair('superseded', true));
      },
    );
  }

  testWidgets(
    'three overlapping writes have one bounded probe; a hung probe never holds the UI',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      var probes = 0, failures = 0, time = 0;
      final pending = List.generate(3, (_) => Completer<void>());
      final telemetry = OperationTelemetry(
        readAccount: () => 'owner',
        emit: (e, _) async => events.add(e),
      );
      final diagnostics = PreparationDiagnostics(
        elapsedMs: () => time,
        probe: (_) {
          probes++;
          return Completer<Map<String, Object>>().future;
        },
      );
      for (var i = 0; i < 3; i++) {
        final attempt = telemetry.start(
          'tv.prepare.request',
          trace: diagnostics.snapshot(),
        );
        unawaited(
          diagnostics
              .observeRequest(
                write: () => pending[i].future,
                attempt: attempt,
                requestId: 'prepare-test-$i',
                superseded: () => false,
              )
              .catchError((Object e) {
                failures++;
                attempt.failure(e);
              }),
        );
      }
      expect(diagnostics.snapshot()['pendingWrites'], 3);
      time = 8000;
      await tester.pump(const Duration(seconds: 8));
      expect(failures, 3);
      expect(probes, 1);
      for (final write in pending) {
        write.complete();
      }
      await tester.pump(const Duration(seconds: 6));
      await telemetry.flush();
      expect(
        events.where(
          (e) => e['action'] == 'tv.prepare.probe' && e['outcome'] == 'failure',
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'successful write never waits for telemetry, probes, or changes class behavior',
    (tester) async {
      var probes = 0;
      final telemetry = OperationTelemetry(
        readAccount: () => 'owner',
        emit: (_, _) => Completer<void>().future,
      );
      final diagnostics = PreparationDiagnostics(
        probe: (_) async {
          probes++;
          return {};
        },
      );
      var completed = false;
      unawaited(
        diagnostics
            .observeRequest(
              write: () async {},
              attempt: telemetry.start('tv.prepare.request'),
              requestId: 'prepare-test-1',
              superseded: () => false,
            )
            .then((_) => completed = true),
      );
      await tester.pump();
      expect(completed, isTrue);
      expect(probes, 0);
      expect(diagnostics.snapshot()['pendingWrites'], 0);
    },
  );

  testWidgets(
    'account change or disposal prevents late telemetry attributed to a new account',
    (tester) async {
      for (final dispose in [false, true]) {
        String? account = 'old';
        final events = <Map<String, dynamic>>[];
        final telemetry = OperationTelemetry(
          readAccount: () => account,
          emit: (e, _) async => events.add(e),
        );
        final diagnostics = PreparationDiagnostics();
        final write = Completer<void>();
        final attempt = telemetry.start('tv.prepare.request');
        unawaited(
          diagnostics
              .observeRequest(
                write: () => write.future,
                attempt: attempt,
                requestId: 'prepare-test-1',
                superseded: () => true,
              )
              .catchError((Object _) {}),
        );
        await tester.pump(const Duration(seconds: 8));
        if (dispose) {
          diagnostics.dispose();
        } else {
          account = 'new';
        }
        write.complete();
        await tester.pump();
        await telemetry.flush();
        expect(
          events.where((e) => e['action'] == 'tv.prepare.settlement'),
          isEmpty,
        );
      }
    },
  );

  test('connection observation age is explicit and arbitrary private data is discarded', () {
    var time = 0;
    final diagnostics = PreparationDiagnostics(elapsedMs: () => time);
    expect(diagnostics.snapshot()['connection'], 'unknown');
    expect(diagnostics.snapshot().containsKey('connectionAgeMs'), isFalse);
    diagnostics.connectionChanged(true);
    diagnostics.lifecycleChanged('resumed');
    time = 5000;
    diagnostics.connectionChanged(false);
    time = 7000;
    expect(diagnostics.snapshot()['connectionChanges'], 1);
    expect(diagnostics.snapshot()['connectionAgeMs'], 2000);
    expect(diagnostics.snapshot()['lifecycleAgeMs'], 7000);
    final safe = safePreparationTrace({
      ...diagnostics.snapshot(),
      'ssid': 'private',
      'requestId': 'private@example.com',
      'targetIndex': -1,
      'parentOperationId': 'token',
      'httpStatus': double.nan,
    });
    expect(safe.toString(), isNot(contains('private')));
    expect(safe.containsKey('targetIndex'), isFalse);
    expect(safe.containsKey('httpStatus'), isFalse);
  });

  test('probe reads one request-ID scalar and reports no token, URL or foreign content', () async {
    for (final value in ['"prepare-test-1"', '"different-secret-id"', 'null']) {
      final client = _Client((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/users/owner/displayPreparation/request/sessionId.json',
        );
        return http.Response(value, 200);
      });
      final result = await probePreparationRequest(
        requestId: 'prepare-test-1',
        ownerId: 'owner',
        databaseUrl: 'https://example.test',
        projectId: 'test',
        isCurrentAccount: () => true,
        readToken: () async => 'secret-token',
        clientFactory: () => client,
      );
      expect(
        result['requestMatch'],
        value == 'null'
            ? 'absent'
            : value.contains('different')
            ? 'different'
            : 'same',
      );
      expect(result.toString(), isNot(contains('secret')));
      expect(client.closed, isTrue);
    }
  });

  testWidgets(
    'probe times out auth and HTTP separately and always closes the HTTP client',
    (tester) async {
      for (final stage in ['auth', 'http']) {
        final client = _Client((_) => Completer<http.Response>().future);
        PreparationProbeFailure? failure;
        unawaited(
          probePreparationRequest(
            requestId: 'prepare-test-1',
            ownerId: 'owner',
            databaseUrl: 'https://example.test',
            projectId: 'test',
            isCurrentAccount: () => true,
            readToken: () => stage == 'auth'
                ? Completer<String?>().future
                : Future.value('secret'),
            clientFactory: () => client,
          ).catchError((Object e) {
            failure = e as PreparationProbeFailure;
            return <String, Object>{};
          }),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(failure?.code, 'timeout');
        expect(failure?.trace['probeStage'], stage);
        expect(client.closed, stage == 'http');
      }
    },
  );

  test('probe suppresses account changes before HTTP and sanitizes transport exceptions', () async {
    var current = true;
    await expectLater(
      probePreparationRequest(
        requestId: 'prepare-test-1',
        ownerId: 'owner',
        databaseUrl: 'https://example.test',
        projectId: 'test',
        isCurrentAccount: () => current,
        readToken: () async {
          current = false;
          return 'token';
        },
        clientFactory: () => throw StateError('must not send'),
      ),
      throwsA(
        isA<PreparationProbeFailure>().having(
          (e) => e.code,
          'code',
          'cancelled',
        ),
      ),
    );
    final client = _Client(
      (_) async =>
          throw http.ClientException('https://private.test?auth=secret'),
    );
    await expectLater(
      probePreparationRequest(
        requestId: 'prepare-test-1',
        ownerId: 'owner',
        databaseUrl: 'https://example.test',
        projectId: 'test',
        isCurrentAccount: () => true,
        readToken: () async => 'token',
        clientFactory: () => client,
      ),
      throwsA(
        isA<PreparationProbeFailure>()
            .having((e) => e.code, 'code', 'unavailable')
            .having(
              (e) => e.trace.toString(),
              'trace',
              isNot(contains('secret')),
            ),
      ),
    );
    expect(client.closed, isTrue);
  });
}

class _Client extends MockClient {
  _Client(super.fn);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}
