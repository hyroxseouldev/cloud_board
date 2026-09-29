import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostic_queue.dart';

class _Sink implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  bool fail = false;
  @override
  Future<void> send(DiagnosticEvent event) async {
    if (fail) throw StateError('sink offline');
    events.add(event);
  }
}

void main() {
  test('handled errors preserve object/stack, deduplicate, isolate context and redact private values', () async {
    final sink = _Sink();
    final reporter = ErrorReporter(
      sink,
      defaults: {'version': '1.0', 'build': '200'},
    );
    final context = <String, Object?>{
      'sessionId': 's1',
      'workoutName': 'private class',
      'phone': '01012345678',
    };
    for (var i = 0; i < 20; i++) {
      reporter.breadcrumb('playback.seek', {'stepIndex': i});
    }
    final original = StateError(
      'permission at https://db/users/private?auth=secret coach@example.com password=hunter2 010-1234-5678',
    );
    final stack = StackTrace.fromString(
      'at https://example.com/main.dart.js:123:45\nat /Users/private/project/main.dart:20',
    );
    final first = reporter.capture(
      original,
      stack,
      action: 'playback.pause',
      context: context,
    );
    context['sessionId'] = 's2';
    reporter.capture(original, stack, action: 'ui.error');
    final second = reporter.capture(
      RangeError.index(8, [1]),
      stack,
      action: 'playback.seek',
      context: context,
    );
    await Future<void>.delayed(Duration.zero);
    expect(sink.events.length, 2);
    expect(identical(first.error, original), isTrue);
    expect(identical(first.stack, stack), isTrue);
    expect(first.context['sessionId'], 's1');
    expect(second.context['sessionId'], 's2');
    expect(first.breadcrumbs.length, 15);
    expect(first.breadcrumbs.first['stepIndex'], 5);
    final encoded = jsonEncode(first.toJson());
    for (final secret in [
      'coach@example.com',
      'hunter2',
      '010-1234-5678',
      '/Users/private',
      'private class',
      'auth=secret',
    ]) {
      expect(encoded, isNot(contains(secret)));
    }
    expect(encoded, contains('main.dart.js:123:45'));
    expect(second.code, 'invalid_index');
    expect(second.context['stepIndex'], 8);
    expect(second.context['stepCount'], 1);
    reporter.resetAccount();
    expect(reporter.eventFor(original), isNull);
    expect(
      reporter
          .capture(StateError('next account'), stack, action: 'new')
          .breadcrumbs,
      isEmpty,
    );
    final firebase = reporter.capture(
      FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
        message: 'denied',
      ),
      stack,
      action: 'playback.stream',
    );
    expect(firebase.context['firebaseCode'], 'permission-denied');
    expect(firebase.code, 'firebase_database/permission-denied');
    sink.fail = true;
    expect(
      () => reporter.capture(
        StateError('failed'),
        stack,
        action: 'playback.recover',
      ),
      returnsNormally,
    );
    await Future<void>.delayed(Duration.zero);
  });
  test('queue persists only bounded unexpired records, retries after network, resets on account switch', () async {
    var now = DateTime.utc(2026, 9, 30);
    String? storage;
    var fail = true;
    final sent = <String>[];
    DiagnosticQueue make() => DiagnosticQueue(
      read: () async => storage,
      write: (v) async => storage = v,
      send: (v, account) async {
        if (fail) throw StateError('offline');
        sent.add(v['eventId'] as String);
      },
      clock: () => now,
      capacity: 2,
    );
    var queue = make();
    await queue.setAccount('a');
    for (var i = 0; i < 4; i++) {
      await queue.enqueue({
        'eventId': 'event-$i',
        'occurredAt': now.toIso8601String(),
      });
    }
    expect((jsonDecode(storage!)['events'] as List).length, 2);
    await queue.flush();
    queue.dispose();
    fail = false;
    queue = make();
    await queue.setAccount('a');
    await queue.flush();
    expect(sent, ['event-2', 'event-3']);
    fail = true;
    await queue.enqueue({
      'eventId': 'expired',
      'occurredAt': now.toIso8601String(),
    });
    now = now.add(const Duration(days: 2));
    fail = false;
    await queue.flush();
    expect(sent, isNot(contains('expired')));
    await queue.setAccount('b');
    expect(storage, isNull);
    await queue.setAccount(null);
    await queue.enqueue({
      'eventId': 'no-account',
      'occurredAt': now.toIso8601String(),
    });
    expect(storage, isNull);
    queue.dispose();
  });
}
