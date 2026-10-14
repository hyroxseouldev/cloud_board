import 'dart:async';

import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_presence_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'disconnect hook registration completes before verify and online',
    () async {
      final transport = StreamController<bool>();
      final registration = Completer<void>();
      final calls = <String>[];
      final coordinator = DisplayPresenceCoordinator(
        newConnectionId: () => 'c1',
        registerDisconnect: (id) {
          calls.add('register:$id');
          return registration.future;
        },
        verify: (id) async {
          calls.add('verify:$id');
        },
        publish: (id, current) async {
          if (current()) calls.add('online:$id');
        },
      );
      coordinator.start(transport.stream);
      transport.add(true);
      await flush();
      expect(calls, ['register:c1']);
      registration.complete();
      await coordinator.firstReady;
      expect(calls, ['register:c1', 'verify:c1', 'online:c1']);
      coordinator.dispose();
      await transport.close();
    },
  );

  test(
    'reconnect serializes stale verification and publishes only new generation',
    () async {
      final transport = StreamController<bool>();
      final verification = Completer<void>();
      final calls = <String>[];
      var serial = 0;
      final coordinator = DisplayPresenceCoordinator(
        newConnectionId: () => 'c${++serial}',
        registerDisconnect: (id) async {
          calls.add('register:$id');
        },
        verify: (id) async {
          calls.add('verify:$id');
          if (id == 'c1') await verification.future;
        },
        publish: (id, current) async {
          if (current()) calls.add('online:$id');
        },
      );
      coordinator.start(transport.stream);
      transport.add(true);
      await flush();
      transport.add(false);
      transport.add(true);
      await flush();
      expect(calls, ['register:c1', 'verify:c1']);
      verification.complete();
      await coordinator.firstReady;
      expect(calls, [
        'register:c1',
        'verify:c1',
        'register:c2',
        'verify:c2',
        'online:c2',
      ]);
      coordinator.dispose();
      await transport.close();
    },
  );

  test('verification rejection never publishes online and retries registration first', () async {
    final transport = StreamController<bool>();
    final calls = <String>[];
    var serial = 0;
    final coordinator = DisplayPresenceCoordinator(
      retryDelays: [Duration.zero],
      newConnectionId: () => 'c${++serial}',
      registerDisconnect: (id) async {
        calls.add('register:$id');
      },
      verify: (id) async {
        calls.add('verify:$id');
        if (id == 'c1') throw StateError('permission-denied');
      },
      publish: (id, current) async {
        if (current()) calls.add('online:$id');
      },
    );
    coordinator.start(transport.stream);
    transport.add(true);
    await coordinator.firstReady;
    expect(calls, [
      'register:c1',
      'verify:c1',
      'register:c2',
      'verify:c2',
      'online:c2',
    ]);
    coordinator.dispose();
    await transport.close();
  });

  test('account disposal during verification cannot publish online', () async {
    final transport = StreamController<bool>();
    final verification = Completer<void>();
    var published = false;
    final coordinator = DisplayPresenceCoordinator(
      newConnectionId: () => 'c1',
      registerDisconnect: (_) async {},
      verify: (_) => verification.future,
      publish: (_, _) async {
        published = true;
      },
    );
    coordinator.start(transport.stream);
    transport.add(true);
    await flush();
    coordinator.dispose();
    verification.complete();
    await flush();
    expect(published, isFalse);
    await transport.close();
  });

  test(
    'old disconnect and root boolean cannot overwrite active connection health',
    () {
      final device = decodeDisplayDevice('tv', {
        'id': 'tv',
        'paired': true,
        'online': false,
        'lastSeenAtMs': 1,
        'presenceProtocol': 1,
        'currentConnectionId': 'new',
        'presence': {
          'old': {'online': false, 'lastSeenAtMs': 100000},
          'new': {'online': true, 'lastSeenAtMs': 99999, 'readyAtMs': 99900},
        },
        'connectionVerification': {
          'connectionId': 'new',
          'verifiedAtMs': 99000,
        },
      });
      expect(device.recentlySeen(100000), isTrue);
      expect(device.connectionAuthenticated(100000), isTrue);
      expect(device.playbackReady(100000), isTrue);
      expect(device.recentlySeen(175000), isFalse);
    },
  );

  test('transport freshness does not imply authenticated or ready', () {
    final device = decodeDisplayDevice('tv', {
      'paired': true,
      'online': true,
      'lastSeenAtMs': 100000,
      'presenceProtocol': 1,
      'currentConnectionId': 'new',
      'presence': {
        'new': {'online': true, 'lastSeenAtMs': 100000},
      },
      'connectionVerification': {'connectionId': 'old', 'verifiedAtMs': 99999},
    });
    expect(device.recentlySeen(100001), isTrue);
    expect(device.connectionAuthenticated(100001), isFalse);
    expect(device.playbackReady(100001), isFalse);
  });

  test('missing scoped presence stays offline despite legacy online true', () {
    final device = decodeDisplayDevice('tv', {
      'paired': true,
      'online': true,
      'lastSeenAtMs': 100000,
      'presenceProtocol': 1,
      'currentConnectionId': 'gone',
    });
    expect(device.recentlySeen(100001), isFalse);
  });

  test('legacy registered TV remains visible with fresh heartbeat only', () {
    final device = decodeDisplayDevice('tv', {
      'paired': true,
      'online': true,
      'lastSeenAtMs': 100000,
    });
    expect(device.recentlySeen(100001), isTrue);
    expect(device.connectionAuthenticated(100001), isFalse);
    expect(device.recentlySeen(90000), isFalse);
  });
  test(
    'a preparation failure overrides a previous successful readiness mark',
    () {
      final device = decodeDisplayDevice('tv', {
        'paired': true,
        'presenceProtocol': 1,
        'currentConnectionId': 'new',
        'presence': {
          'new': {'online': true, 'lastSeenAtMs': 100000, 'readyAtMs': 99999},
        },
        'connectionVerification': {
          'connectionId': 'new',
          'verifiedAtMs': 99000,
        },
        'preparationHealth': {
          'stage': 'media',
          'code': 'image_load_failed',
          'checkedAtMs': 100000,
        },
      });
      expect(device.connectionAuthenticated(100001), isTrue);
      expect(device.playbackReady(100001), isFalse);
    },
  );

  test('exhausted presence retries fail without publishing online', () async {
    final transport = StreamController<bool>();
    var published = false;
    final coordinator = DisplayPresenceCoordinator(
      retryDelays: [],
      newConnectionId: () => 'c1',
      registerDisconnect: (_) async {},
      verify: (_) async => throw StateError('permission-denied'),
      publish: (_, _) async {
        published = true;
      },
    );
    final failed = expectLater(coordinator.firstReady, throwsStateError);
    coordinator.start(transport.stream);
    transport.add(true);
    await failed;
    expect(coordinator.exhausted, isTrue);
    expect(published, isFalse);
    coordinator.dispose();
    await transport.close();
  });
}
