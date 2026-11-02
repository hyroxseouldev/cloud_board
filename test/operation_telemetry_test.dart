import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';

void main() {
  test('old collector fallback sends the unchanged 2.0.5 shape once; outages never cause fallback', () async {
    final payload = <String, dynamic>{
      'action': 'tv.prepare.request',
      'operationId': 'a' * 32,
      'outcome': 'failure',
      'trace': {'connection': 'disconnected'},
    };
    final sent = <Map<String, dynamic>>[];
    await sendCompatibleOperation(payload, (value) async {
      sent.add(value);
      if (value.containsKey('trace')) {
        throw FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'old collector',
          details: null,
        );
      }
    });
    expect(sent, [payload, Map<String, dynamic>.of(payload)..remove('trace')]);
    expect(payload.containsKey('trace'), isTrue);
    var calls = 0;
    await expectLater(
      sendCompatibleOperation(payload, (_) async {
        calls++;
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'offline',
          details: null,
        );
      }),
      throwsA(isA<FirebaseFunctionsException>()),
    );
    expect(calls, 1);
  });
  test('trace snapshots are immutable, sanitized and retain the request correlation at completion', () async {
    final events = <Map<String, dynamic>>[];
    final telemetry = OperationTelemetry(
      readAccount: () => 'owner',
      emit: (e, _) async => events.add(e),
    );
    final trace = <String, Object?>{
      'requestId': 'prepare-test-1',
      'connection': 'connected',
      'ssid': 'private',
    };
    final attempt = telemetry.start('tv.prepare.request', trace: trace);
    trace['connection'] = 'disconnected';
    attempt.failure(
      'timeout',
      trace: {'connection': 'disconnected', 'pendingWrites': 1},
    );
    await telemetry.flush();
    expect(events.first['trace'], {
      'requestId': 'prepare-test-1',
      'connection': 'connected',
    });
    expect(events.last['trace'], {
      'requestId': 'prepare-test-1',
      'connection': 'disconnected',
      'pendingWrites': 1,
    });
    expect(events.toString(), isNot(contains('private')));
    telemetry.start('workout.save', trace: trace).success();
    await telemetry.flush();
    expect(events.last.containsKey('trace'), isFalse);
  });
  test('attempt stays pending until explicit completion; terminal result emits once', () async {
    final events = <Map<String, dynamic>>[];
    final telemetry = OperationTelemetry(
      readAccount: () => 'account',
      emit: (event, _) async => events.add(event),
      createId: () => 'a' * 32,
    );
    final attempt = telemetry.start('workout.save');
    await telemetry.flush();
    expect(events.map((e) => e['outcome']), ['attempt']);
    attempt.failure('permission-denied');
    attempt.success();
    await telemetry.flush();
    expect(events.map((e) => e['outcome']), ['attempt', 'failure']);
    expect(events.last['code'], 'permission-denied');
    expect(events.last['operationId'], events.first['operationId']);
    expect(events.first.keys, isNot(contains('accountId')));
  });
  test('account changes suppress pending completion and failures cannot affect product action', () async {
    String? owner = 'first';
    final events = <Map<String, dynamic>>[];
    final telemetry = OperationTelemetry(
      readAccount: () => owner,
      emit: (event, _) async {
        events.add(event);
        throw StateError('network');
      },
    );
    final attempt = telemetry.start('tv.prepare');
    await telemetry.flush();
    owner = 'second';
    attempt.success();
    await telemetry.flush();
    expect(events.length, 1);
    owner = null;
    telemetry.start('workout.save').success();
    await telemetry.flush();
    expect(events.length, 1);
  });
  test('explicit cancellation is separate and arbitrary error strings are discarded', () async {
    final events = <Map<String, dynamic>>[];
    final telemetry = OperationTelemetry(
      readAccount: () => 'account',
      emit: (event, _) async => events.add(event),
    );
    telemetry.start('tv.prepare').cancel();
    telemetry.start('playback.control.submit').failure('private@example.com');
    await telemetry.flush();
    expect(events.map((e) => e['outcome']), [
      'attempt',
      'cancelled',
      'attempt',
      'failure',
    ]);
    expect(events.last['code'], 'unexpected');
    expect(events.toString(), isNot(contains('private@example')));
  });
}
