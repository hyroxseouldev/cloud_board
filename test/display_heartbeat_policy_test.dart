import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/runtime_policy/display_heartbeat_policy_service.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> rollout({
  int revision = 1,
  int interval = 60,
  int timeout = 180,
}) => {
  ...DisplayHeartbeatPolicy.target.toJson(),
  'revision': revision,
  'heartbeatIntervalSeconds': interval,
  'noResponseTimeoutSeconds': timeout,
};

void main() {
  test(
    'invalid or partial atomic policy never supplies only half the timings',
    () {
      for (final patch in <Map<String, dynamic>>[
        {'schemaVersion': 2},
        {'revision': -1},
        {'revision': '1'},
        {'heartbeatIntervalSeconds': null},
        {'heartbeatIntervalSeconds': 1},
        {'heartbeatIntervalSeconds': 121},
        {'noResponseTimeoutSeconds': 75},
        {'noResponseTimeoutSeconds': 601},
      ]) {
        expect(
          () => DisplayHeartbeatPolicy.fromJson({...rollout(), ...patch}),
          throwsFormatException,
        );
      }
      final policy = DisplayHeartbeatPolicy.fromJson(rollout());
      expect(policy.heartbeatIntervalSeconds, 60);
      expect(policy.noResponseTimeoutSeconds, 180);
    },
  );

  test('last good survives offline restart; stale and reused revisions cannot replace it', () async {
    String? cache;
    Map<String, dynamic>? remote = rollout(revision: 5);
    var reads = 0;
    DisplayHeartbeatPolicyService service() => DisplayHeartbeatPolicyService(
      fetch: () async => remote,
      readCache: () async {
        reads++;
        return cache;
      },
      writeCache: (value) async => cache = value,
    );
    final first = service();
    expect((await first.load()).interval.inSeconds, 60);
    expect(jsonDecode(cache!)['revision'], 5);
    remote = {'schemaVersion': 1};
    expect((await first.load()).revision, 5);
    remote = rollout(revision: 4, interval: 20, timeout: 75);
    expect((await first.load()).interval.inSeconds, 60);
    remote = rollout(revision: 5, interval: 20, timeout: 75);
    expect((await first.load()).interval.inSeconds, 60);
    expect(reads, 1);
    remote = null;
    expect((await service().load()).revision, 5);
    remote = rollout(revision: 6, interval: 20, timeout: 75);
    final rollback = await first.load();
    expect(rollback.interval.inSeconds, 20);
    expect(rollback.revision, 6);
  });

  test('bad cache and fetch failure use 60/180 timing; simultaneous loads share fetch', () async {
    final gate = Completer<Map<String, dynamic>?>();
    var calls = 0;
    final service = DisplayHeartbeatPolicyService(
      fetch: () {
        calls++;
        return gate.future;
      },
      readCache: () async => 'invalid',
      writeCache: (_) async => throw StateError('storage unavailable'),
    );
    final one = service.load(), two = service.load();
    gate.completeError(StateError('offline'));
    final results = await Future.wait([one, two]);
    expect(calls, 1);
    expect(results.every((value) => value.interval.inSeconds == 60), isTrue);
  });

  test('playing and paused sessions freeze before pending policy; standby accepts rollback', () {
    final next = DisplayHeartbeatPolicy.fromJson(rollout());
    final selection = DisplayHeartbeatSelection(DisplayHeartbeatPolicy.legacy);
    selection.setStandby(false);
    selection.pending = next;
    expect(selection.begin().interval.inSeconds, 20);
    selection.setStandby(false); // paused is still non-standby
    expect(selection.begin().interval.inSeconds, 20);
    selection.setStandby(true);
    expect(selection.begin(), same(next));
    selection.setStandby(
      false,
    ); // delivery was already in flight at class start
    selection.accepted(next);
    selection.pending = DisplayHeartbeatPolicy.fromJson(
      rollout(revision: 2, interval: 20, timeout: 75),
    );
    expect(selection.begin().interval.inSeconds, 60);
    selection.setStandby(true);
    expect(selection.begin().interval.inSeconds, 20);
    expect(selection.begin().revision, 2);
  });

  test(
    'empty local cache cannot overwrite a newer applied connection policy',
    () {
      final policy = DisplayHeartbeatPolicy.fromJson(rollout(revision: 5));
      final selection = DisplayHeartbeatSelection(policy)
        ..pending = DisplayHeartbeatPolicy.legacy;
      expect(selection.begin(), same(policy));
    },
  );

  test('controller freshness uses current device policy, independent of when the controller fetched Remote Config', () {
    Map<String, dynamic> device({Object? policy, bool online = true}) => {
      'paired': true,
      'presenceProtocol': 1,
      'currentConnectionId': 'new',
      'presence': {
        'new': {'online': online, 'lastSeenAtMs': 100000},
      },
      'heartbeatPolicy': policy,
    };
    final policy = {...rollout(), 'connectionId': 'new'};
    final modern = decodeDisplayDevice('tv', device(policy: policy));
    expect(modern.recentlySeen(279999), isTrue);
    expect(modern.recentlySeen(280000), isFalse);
    expect(modern.recentlySeen(90000), isFalse);
    expect(
      decodeDisplayDevice(
        'tv',
        device(policy: policy, online: false),
      ).recentlySeen(100001),
      isFalse,
    );
    for (final value in [
      null,
      {...policy, 'connectionId': 'old'},
      {...policy, 'noResponseTimeoutSeconds': 75},
    ]) {
      final fallback = decodeDisplayDevice('tv', device(policy: value));
      expect(fallback.recentlySeen(174999), isTrue);
      expect(fallback.recentlySeen(175000), isFalse);
    }
  });
}
