import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';

final workout =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: '테스트 수업',
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('m')
            .copyWith(workSeconds: 1, restSeconds: 0, sets: 1, beep: false),
      ],
    );

class _Workouts extends WorkoutController {
  @override
  Stream<List<Workout>> build() => Stream.value([workout]);
}

class _Media implements WorkoutMediaController {
  int hidden = 0;
  @override
  Stream<WorkoutMediaCommand> get commands => const Stream.empty();
  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) async {}
  @override
  Future<void> hide() async {
    hidden++;
  }
}

void main() {
  for (final scenario in ['natural', 'manual', 'remote-removed']) {
    testWidgets(
      '$scenario returns to origin and clears notification without completion screen',
      (tester) async {
        final media = _Media();
        final sessions = StreamController<PlaybackSession?>();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('수업 시작한 화면')),
            ),
            GoRoute(
              path: '/player',
              builder: (_, _) => WorkoutPlayerScreen(
                workoutId: 'w',
                startModule: 0,
                sessionId: scenario == 'remote-removed' ? 's' : null,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutControllerProvider.overrideWith(_Workouts.new),
              workoutMediaControllerProvider.overrideWithValue(media),
              activePlaybackSessionProvider.overrideWith(
                (ref) => sessions.stream,
              ),
              playbackConnectionProvider.overrideWith(
                (ref) => Stream.value(true),
              ),
              serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
              androidTvProvider.overrideWith((ref) async => false),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(router.push('/player'));
        await tester.pump();
        if (scenario == 'remote-removed') {
          sessions.add(
            PlaybackSessionModel.fromWorkout(
              id: 's',
              ownerId: 'u',
              zoneId: 'main',
              targetDeviceIds: [],
              workout: workout,
              stepIndex: 0,
              durationMs: 60000,
              deviceId: 'd',
            ).toEntity().copyWith(
              anchorServerMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else {
          sessions.add(null);
        }
        await tester.pump();
        await tester.pump();
        expect(find.byType(WorkoutBriefingBoard), findsNothing);
        if (scenario == 'manual') {
          await tester.tap(find.text('종료하기'));
          await tester.pumpAndSettle();
          expect(find.text('수업을 종료할까요?'), findsOneWidget);
          await tester.tap(find.text('수업 종료'));
        } else if (scenario == 'natural') {
          await tester.pump(const Duration(milliseconds: 1200));
        } else {
          sessions.add(null);
        }
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('WORKOUT DONE'), findsNothing);
        expect(find.text('수업 시작한 화면'), findsOneWidget);
        expect(media.hidden, greaterThan(0));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        unawaited(sessions.close());
        await tester.pumpAndSettle();
      },
    );
  }
}
