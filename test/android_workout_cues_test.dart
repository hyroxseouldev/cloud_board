import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/core/services/android_cue_audio.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_audio_cues.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/android_workout_cues.dart';
import 'package:flutter_test/flutter_test.dart';

import 'playback_audio_cues_test.dart' show audioSession;

class FakeAudio extends AndroidCueAudio {
  Completer<void>? preparation;
  final calls = <String>[];
  List<Map<String, Object>> cues = [];
  Object? failure;
  @override
  Future<void> activate(String owner, {String? terminalCueId}) async {
    calls.add('activate:$owner');
  }

  @override
  Future<void> prepare(String key, Future<Uint8List> Function() bytes) async {
    await preparation?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> replace(
    String owner,
    List<Map<String, Object>> value,
    double volume,
  ) async {
    calls.add('replace:$owner');
    cues = value;
  }

  @override
  Future<void> cancel(String owner, {bool preserveEnd = false}) async {
    calls.add('cancel:$owner');
  }

  @override
  Future<void> immediate(
    String owner,
    Map<String, Object> cue,
    double volume,
  ) async {
    calls.add('immediate:$owner');
  }
}

void main() {
  test(
    'manual starts received at different times share one server deadline',
    () async {
      final plan = PlaybackAudioPlan(audioSession().copyWith(startDelayMs: 0));
      final serverDeadlines = <int>[];
      for (final (receivedAt, offset) in [
        (10080, 200),
        (10370, -90),
        (10490, 45),
      ]) {
        final audio = FakeAudio();
        var now = receivedAt - offset;
        final controller = AndroidWorkoutCues(
          audio: audio,
          plan: plan,
          offsetMs: offset,
          nowMs: () => now,
          onFailure: (_, _) => fail('unexpected'),
        );
        final cue = plan.recentCommand(receivedAt)!;
        await controller.start(explicitCue: cue);
        final queued = audio.cues.singleWhere((c) => c['id'] == cue.id);
        serverDeadlines.add((queued['localDeadlineMs'] as int) + offset);
        expect(audio.calls.where((c) => c.startsWith('immediate:')), isEmpty);
        now = 10650 - offset;
        await controller.refresh();
        expect(audio.cues.singleWhere((c) => c['id'] == cue.id), queued);
        now = 10751 - offset;
        await controller.refresh();
        expect(audio.cues.where((c) => c['id'] == cue.id), isEmpty);
        controller.cancel();
      }
      expect(serverDeadlines, [10750, 10750, 10750]);
    },
  );

  test(
    'sound loading uses the original deadline, never a new relative delay',
    () async {
      for (final preparedAt in [10600, 10800]) {
        final audio = FakeAudio()..preparation = Completer<void>();
        var now = 10100;
        final plan = PlaybackAudioPlan(
          audioSession().copyWith(startDelayMs: 0),
        );
        final cue = plan.recentCommand(now)!;
        final controller = AndroidWorkoutCues(
          audio: audio,
          plan: plan,
          offsetMs: 0,
          nowMs: () => now,
          onFailure: (_, _) => fail('unexpected'),
        );
        final start = controller.start(explicitCue: cue);
        await Future<void>.delayed(Duration.zero);
        now = preparedAt;
        audio.preparation!.complete();
        await start;
        expect(
          audio.cues
              .where((c) => c['id'] == cue.id)
              .map((c) => c['localDeadlineMs']),
          preparedAt < 10750 ? [10750] : isEmpty,
        );
        expect(audio.calls.where((c) => c.startsWith('immediate:')), isEmpty);
        controller.cancel();
      }
    },
  );

  test(
    'preparation countdown and explicit end retain immediate behavior',
    () async {
      final start = audioSession();
      for (final session in [
        start,
        start.copyWith(startDelayMs: 0, timerCompleted: true),
      ]) {
        final audio = FakeAudio();
        final plan = PlaybackAudioPlan(session);
        final cue = plan.recentCommand(10100)!;
        final controller = AndroidWorkoutCues(
          audio: audio,
          plan: plan,
          offsetMs: 0,
          nowMs: () => 10100,
          onFailure: (_, _) => fail('unexpected'),
        );
        await controller.start(explicitCue: cue);
        expect(
          audio.calls.where((c) => c.startsWith('immediate:')),
          hasLength(1),
        );
        expect(audio.cues.where((c) => c['id'] == cue.id), isEmpty);
        controller.cancel();
      }
    },
  );

  test(
    'preparation finishing after cancel cannot rearm or send stale cues',
    () async {
      final audio = FakeAudio()..preparation = Completer<void>();
      final controller = AndroidWorkoutCues(
        audio: audio,
        plan: PlaybackAudioPlan(audioSession()),
        offsetMs: 200,
        nowMs: () => 10000,
        onFailure: (_, _) => fail('unexpected'),
      );
      final start = controller.start();
      await Future<void>.delayed(Duration.zero);
      controller.cancel();
      audio.preparation!.complete();
      await start;
      expect(audio.calls, [
        'activate:${controller.owner}',
        'cancel:${controller.owner}',
      ]);
    },
  );
  test('native gets absolute local deadline, distinct poll phases do not add relative delay', () async {
    final audio = FakeAudio();
    var now = 10011;
    final controller = AndroidWorkoutCues(
      audio: audio,
      plan: PlaybackAudioPlan(audioSession()),
      offsetMs: 300,
      nowMs: () => now,
      onFailure: (_, _) => fail('unexpected'),
    );
    await controller.start();
    final deadlines = audio.cues.map((c) => c['localDeadlineMs']).toList();
    now = 10089;
    await controller.refresh();
    expect(audio.cues.map((c) => c['localDeadlineMs']), deadlines);
    expect(deadlines.first, 10700);
    controller.cancel();
  });
  test('failure cancels native lease once and reports, never retries AI/server/audio loop', () async {
    final audio = FakeAudio()..failure = StateError('load failed');
    var failures = 0;
    final controller = AndroidWorkoutCues(
      audio: audio,
      plan: PlaybackAudioPlan(audioSession()),
      offsetMs: 0,
      nowMs: () => 10000,
      onFailure: (_, _) => failures++,
    );
    await controller.start();
    await controller.refresh();
    expect(failures, 1);
    expect(audio.calls.where((c) => c.startsWith('cancel')), hasLength(1));
    expect(audio.calls.where((c) => c.startsWith('replace')), isEmpty);
  });
  test(
    'prepared explicit cue expires while loading and is never replayed',
    () async {
      final audio = FakeAudio()..preparation = Completer<void>();
      var now = 10100;
      final plan = PlaybackAudioPlan(audioSession().copyWith(startDelayMs: 0));
      final controller = AndroidWorkoutCues(
        audio: audio,
        plan: plan,
        offsetMs: 0,
        nowMs: () => now,
        onFailure: (_, _) => fail('unexpected'),
      );
      final start = controller.start(explicitCue: plan.recentCommand(now));
      await Future<void>.delayed(Duration.zero);
      now = 11000;
      audio.preparation!.complete();
      await start;
      expect(audio.calls.where((c) => c.startsWith('immediate')), isEmpty);
      controller.cancel();
    },
  );
}
