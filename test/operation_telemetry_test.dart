import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';

void main() {
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
