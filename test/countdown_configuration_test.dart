import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
);

void main() {
  for (final seconds in [0, 17, 60]) {
    test(
      'new session bypasses briefing and starts with $seconds second countdown',
      () async {
        final model = PlaybackSessionModel.fromWorkout(
          id: 'session',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: ['tv'],
          workout: workout.copyWith(countdownSeconds: seconds),
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'controller',
        );
        final local = _Local(model);
        final remote = _Remote(model);
        final started = await PlaybackRepositoryImpl(remote, local, 'u').start(
          workout: workout.copyWith(countdownSeconds: seconds),
          targetDeviceIds: ['tv'],
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'controller',
        );
        expect(started.briefing, isFalse);
        expect(started.startDelayMs, seconds * 1000);
        expect(local.model.startDelayMs, seconds * 1000);
        expect(started.targetDeviceIds, ['tv']);
      },
    );

    test(
      'begin sends $seconds seconds to the current briefing session',
      () async {
        final model = PlaybackSessionModel.fromWorkout(
          id: 'session',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: ['tv'],
          workout: workout.copyWith(countdownSeconds: seconds),
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'controller',
          briefing: true,
        );
        final local = _Local(model);
        final remote = _Remote(model);
        await PlaybackRepositoryImpl(
          remote,
          local,
          'u',
        ).begin(deviceId: 'controller');
        expect(remote.delay, seconds * 1000);
        expect(
          local.delay,
          isNull,
        ); // No optimistic cache write before acknowledgement.
        expect(remote.sessionId, 'session');
        expect(remote.briefingRequired, isTrue);
      },
    );
  }
  testWidgets(
    'editing partial colors keeps last valid color and countdown can be disabled',
    (tester) async {
      var draft = workout;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: CountdownSettings(
                    workout: draft,
                    onChanged: (v) => setState(() => draft = v),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final field = find.byType(TextFormField).last;
      await tester.enterText(field, '#12');
      await tester.pump();
      expect(draft.countdownBackgroundColor, 0xFF000000);
      expect(tester.takeException(), isNull);
      await tester.enterText(field, '#FFFFFF');
      await tester.pump();
      expect(draft.countdownBackgroundColor, 0xFFFFFFFF);
      await tester.enterText(
        find.byKey(const ValueKey('countdown-seconds')),
        '0',
      );
      await tester.pump();
      expect(draft.countdownSeconds, 0);
      expect(find.text('바로 시작 (카운트다운 없음)'), findsOneWidget);
    },
  );
}

class _Local implements PlaybackSessionLocalDataSource {
  _Local(this.model);
  PlaybackSessionModel model;
  int? delay;
  @override
  Future<PlaybackSessionModel?> load() async => model;
  @override
  Future<void> save(PlaybackSessionModel value) async {
    model = value;
  }

  @override
  Future<PlaybackSessionModel?> update({
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
  }) async {
    delay = startDelayMs;
    return model;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Remote implements PlaybackRealtimeDataSource {
  _Remote(this.model);
  final PlaybackSessionModel model;
  @override
  Future<PlaybackSessionModel> start(
    PlaybackSessionModel value, {
    bool scheduled = false,
    int? scheduledAtMs,
  }) async => value;
  int? delay;
  String? sessionId;
  bool? briefingRequired;
  @override
  Future<PlaybackSessionModel> update({
    required String? status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
    required String expectedSessionId,
    required int expectedRevision,
  }) async {
    delay = startDelayMs;
    sessionId = expectedSessionId;
    briefingRequired = requireBriefing;
    return model;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
