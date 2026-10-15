import 'dart:async';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_preparation_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/prepare_display_media.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
);
const now = 100000;
DisplayDevice device(
  String id, {
  int protocol = 1,
  int preparation = 1,
  bool online = true,
  int seen = now,
  DisplayPreparationHealth health = const DisplayPreparationHealth(),
}) => DisplayDevice(
  id: id,
  name: id,
  zoneId: 'main',
  zoneName: '',
  online: online,
  lastSeenAtMs: seen,
  currentSessionId: 'old-session',
  acknowledgedRevision: 999,
  paired: true,
  playbackProtocol: protocol,
  preparationProtocol: preparation,
  preparationHealth: health,
);
DisplayPreparation request({List<String> targets = const ['tv']}) =>
    prepareDisplayCandidate(
      workout,
      targets,
      sessionId: 'prepare-test-1',
      revision: 3,
      nowMs: now,
    );
DisplayPreparationReceipt receipt(
  DisplayPreparation r, {
  int? revision,
  String? sessionId,
  bool audio = true,
  String status = 'ready',
  int? imageCount,
}) => DisplayPreparationReceipt(
  sessionId: sessionId ?? r.sessionId,
  revision: revision ?? r.revision,
  manifestHash: r.manifestHash,
  checkedAtMs: now,
  status: status,
  imageCount: imageCount ?? r.images.length,
  audioReady: audio,
);
DisplayPreparationProof proof(DisplayPreparation r) => DisplayPreparationProof(
  manifestHash: r.manifestHash,
  sessionId: r.sessionId,
  revision: r.revision,
);

void main() {
  test('failed heartbeat or response health cannot reuse a successful receipt as ready', () {
    final candidate = request();
    for (final stage in [
      'heartbeat',
      'response_write',
      'request_read',
      'media',
    ]) {
      final failed = device(
        'tv',
        health: DisplayPreparationHealth(
          stage: stage,
          code: 'unavailable',
          attempt: 4,
          checkedAtMs: now,
          requestId: candidate.sessionId,
        ),
      );
      expect(
        displayPreparationStatus(failed, 1, candidate, receipt(candidate), now),
        DisplayPreparationStatus.failed,
      );
    }
    final previous = device(
      'tv',
      health: const DisplayPreparationHealth(
        stage: 'media',
        code: 'unavailable',
        requestId: 'previous-request',
      ),
    );
    expect(
      displayPreparationStatus(previous, 1, candidate, receipt(candidate), now),
      DisplayPreparationStatus.ready,
    );
  });
  test('server offset aligns skewed phone and TV with receipt expiry', () {
    const local = now - 300000;
    final corrected = preparationServerNow(300000, localNowMs: local);
    expect(corrected, now);
    final candidate = prepareDisplayCandidate(
      workout,
      ['tv'],
      sessionId: 'prepare-offset',
      revision: 1,
      nowMs: corrected,
    );
    expect(candidate.expiresAtMs, now + 90000);
    expect(receipt(candidate).readyFor(candidate, corrected), isTrue);
    expect(receipt(candidate).readyFor(candidate, local), isFalse);
  });
  test('only exact unexpired candidate and revision with actual image/audio success is ready', () {
    final r = request();
    expect(receipt(r).readyFor(r, now), isTrue);
    for (final bad in [
      receipt(r, revision: 2),
      receipt(r, revision: 4),
      receipt(r, sessionId: 'another'),
      receipt(r, audio: false),
      receipt(r, status: 'failed'),
      receipt(r, imageCount: 1),
    ]) {
      expect(bad.readyFor(r, now), isFalse);
    }
    expect(receipt(r).readyFor(r, r.expiresAtMs), isFalse);
    expect(
      displayPreparationStatus(device('tv'), 1, r, null, now),
      DisplayPreparationStatus.waiting,
      reason: 'Display ACK=999 on old session never proves media readiness',
    );
  });
  test(
    'offline, stale, old unknown and insufficient protocol never appear ready',
    () {
      final r = request();
      expect(
        displayPreparationStatus(
          device('tv', online: false),
          1,
          r,
          receipt(r),
          now,
        ),
        DisplayPreparationStatus.offline,
      );
      expect(
        displayPreparationStatus(device('tv', seen: 1), 1, r, receipt(r), now),
        DisplayPreparationStatus.offline,
      );
      expect(
        displayPreparationStatus(
          device('tv', preparation: 0),
          1,
          r,
          receipt(r),
          now,
        ),
        DisplayPreparationStatus.legacy,
      );
      expect(
        displayPreparationStatus(
          device('tv', protocol: 1),
          5,
          r,
          receipt(r),
          now,
        ),
        DisplayPreparationStatus.updateRequired,
      );
    },
  );
  test('workout settings and selected TVs invalidate candidate identity', () {
    final hash = preparationFingerprint(workout, ['a', 'b']);
    expect(hash, preparationFingerprint(workout, ['b', 'a']));
    expect(
      hash,
      isNot(
        preparationFingerprint(workout.copyWith(soundVolume: 0), ['a', 'b']),
      ),
    );
    expect(hash, isNot(preparationFingerprint(workout, ['a'])));
  });
  test(
    'start rechecks latest candidate, final preferences, receipt and heartbeat',
    () async {
      final r = request(), repository = _Preparation()..value = request();
      repository.acks = {'tv': receipt(r)};
      final devices = _Devices([device('tv')]);
      final actions = DisplayPreparationActions(repository, devices);
      await actions.verifyStart(workout, ['tv'], proof(r), nowMs: now);
      await expectLater(
        actions.verifyStart(workout, ['tv'], null, nowMs: now),
        throwsStateError,
      );
      await expectLater(
        actions.verifyStart(
          workout.copyWith(name: 'Changed'),
          ['tv'],
          proof(r),
          nowMs: now,
        ),
        throwsStateError,
      );
      repository.acks = {'tv': receipt(r, revision: 2)};
      await expectLater(
        actions.verifyStart(workout, ['tv'], proof(r), nowMs: now),
        throwsStateError,
      );
      repository.acks = {'tv': receipt(r)};
      devices.values = [device('tv', online: false)];
      await expectLater(
        actions.verifyStart(workout, ['tv'], proof(r), nowMs: now),
        throwsStateError,
      );
      devices.values = [device('tv')];
      await expectLater(
        actions.verifyStart(workout, ['tv'], proof(r), nowMs: r.expiresAtMs),
        throwsStateError,
      );
    },
  );
  test('compatible legacy TVs start automatically after connection and protocol checks', () async {
    final r = request();
    final actions = DisplayPreparationActions(
      _Preparation(),
      _Devices([device('tv', preparation: 0)]),
    );
    await actions.verifyStart(workout, ['tv'], null, nowMs: now);
    await actions.verifyStart(workout, ['tv'], proof(r), nowMs: now);
  });
  test('mixed displays still require the modern candidate receipt', () async {
    final candidate = request(targets: ['old', 'tv']);
    final repository = _Preparation()..value = candidate;
    final devices = _Devices([device('old', preparation: 0), device('tv')]);
    final actions = DisplayPreparationActions(repository, devices);
    await expectLater(
      actions.verifyStart(workout, ['old', 'tv'], proof(candidate), nowMs: now),
      throwsStateError,
    );
    repository.acks = {'tv': receipt(candidate)};
    await actions.verifyStart(
      workout,
      ['old', 'tv'],
      proof(candidate),
      nowMs: now,
    );
    devices.values = [
      device('old', preparation: 0, seen: now - 75000),
      device('tv'),
    ];
    await expectLater(
      actions.verifyStart(workout, ['old', 'tv'], proof(candidate), nowMs: now),
      throwsStateError,
    );
  });
  test(
    'stale legacy TV cannot start with or without preparation proof',
    () async {
      final candidate = request();
      final stale = device('tv', preparation: 0, seen: now - 75000);
      final actions = DisplayPreparationActions(
        _Preparation(),
        _Devices([stale]),
        serverNow: () async => now,
      );
      expect(
        displayPreparationStatus(stale, 1, null, null, now),
        DisplayPreparationStatus.offline,
      );
      await expectLater(
        actions.verifyStart(workout, ['tv'], proof(candidate)),
        throwsStateError,
      );
      await expectLater(
        actions.verifyStart(workout, ['tv'], null),
        throwsStateError,
      );
    },
  );
  test(
    'a current health failure blocks start despite a successful receipt',
    () async {
      final candidate = request();
      final repository = _Preparation()
        ..value = candidate
        ..acks = {'tv': receipt(candidate)};
      final actions = DisplayPreparationActions(
        repository,
        _Devices([
          device(
            'tv',
            health: DisplayPreparationHealth(
              stage: 'heartbeat',
              code: 'unavailable',
              attempt: 4,
              checkedAtMs: now,
              requestId: candidate.sessionId,
            ),
          ),
        ]),
        serverNow: () async => now,
      );
      expect(receipt(candidate).readyFor(candidate, now), isTrue);
      await expectLater(
        actions.verifyStart(workout, ['tv'], proof(candidate)),
        throwsStateError,
      );
    },
  );
  test('image or audio failure cannot become readiness, and cancellation emits nothing', () async {
    final r = request();
    var audioCalls = 0;
    final failures = <(String, Object, StackTrace)>[];
    final imageError = StateError('image');
    final imageFailure = await prepareDisplayMedia(
      r,
      images: (_) async => throw imageError,
      audio: (_) async {
        audioCalls++;
      },
      cancelled: () => false,
      onError: (stage, error, stack) => failures.add((stage, error, stack)),
    );
    expect(imageFailure!.ready, isFalse);
    expect(audioCalls, 0);
    final audioFailure = await prepareDisplayMedia(
      r,
      images: (_) async => 0,
      audio: (_) async => throw StateError('native source'),
      cancelled: () => false,
      onError: (stage, error, stack) => failures.add((stage, error, stack)),
    );
    expect(audioFailure!.ready, isFalse);
    expect(audioFailure.audioReady, isFalse);
    expect(failures.map((failure) => failure.$1), ['images', 'audio']);
    expect(failures.first.$2, same(imageError));
    expect(
      failures.every((failure) => failure.$3.toString().isNotEmpty),
      isTrue,
    );
    var cancelled = false;
    expect(
      await prepareDisplayMedia(
        r,
        images: (_) async {
          cancelled = true;
          return 0;
        },
        audio: (_) async {
          audioCalls++;
        },
        cancelled: () => cancelled,
      ),
      isNull,
    );
    expect(audioCalls, 0);
    expect(
      (await prepareDisplayMedia(
        r,
        images: (_) async => 0,
        audio: (_) async {},
        cancelled: () => false,
      ))!.ready,
      isTrue,
    );
  });
}

class _Devices implements DevicePairingRepository {
  _Devices(this.values);
  List<DisplayDevice> values;
  @override
  Stream<List<DisplayDevice>> watchDevices() => Stream.value(values);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preparation implements DisplayPreparationRepository {
  DisplayPreparation? value;
  Map<String, DisplayPreparationReceipt> acks = {};
  @override
  Future<DisplayPreparation?> current() async => value;
  @override
  Future<Map<String, DisplayPreparationReceipt>> receipts() async => acks;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
