import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  _Workouts(this.value);
  final Workout value;
  @override
  Stream<List<Workout>> build() => Stream.value([value]);
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
  for (final scenario in [
    'natural',
    'manual',
    'remote-removed',
    'remote-manual',
  ]) {
    testWidgets(
      '$scenario returns to origin and clears notification without completion screen',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]),
            );
        final media = _Media();
        final sessions = StreamController<PlaybackSession?>();
        final session =
            PlaybackSessionModel.fromWorkout(
              id: 's',
              ownerId: 'u',
              zoneId: 'main',
              targetDeviceIds: [],
              workout: workout.copyWith(
                modules: [workout.modules.single.copyWith(workSeconds: 600)],
              ),
              stepIndex: 0,
              durationMs: 600000,
              deviceId: 'd',
            ).toEntity().copyWith(
              anchorServerMs: DateTime.now().millisecondsSinceEpoch,
            );
        final complete = _Complete(
          () => sessions.add(
            session.copyWith(status: PlaybackStatus.completed, remainingMs: 0),
          ),
        );

        final router = GoRouter(
          initialLocation: '/origin',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('홈')),
            ),
            GoRoute(
              path: '/origin',
              builder: (_, _) => const Scaffold(body: Text('수업 시작한 화면')),
            ),
            GoRoute(
              path: '/player',
              builder: (_, _) => WorkoutPlayerScreen(
                workoutId: 'w',
                startModule: 0,
                sessionId: scenario.startsWith('remote-') ? 's' : null,
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutControllerProvider.overrideWith(
                () => _Workouts(
                  // Dialog animation must not race the one-second natural-end case
                  // on slower CI machines, where wall-clock deadlines keep advancing.
                  scenario == 'manual'
                      ? workout.copyWith(
                          modules: [
                            workout.modules.single.copyWith(workSeconds: 600),
                          ],
                        )
                      : workout,
                ),
              ),
              workoutMediaControllerProvider.overrideWithValue(media),
              playbackActionControllerProvider.overrideWith(() => complete),
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
        if (scenario.startsWith('remote-')) {
          sessions.add(session);
        } else {
          sessions.add(null);
        }
        await tester.pump();
        await tester.pump();
        expect(find.byType(WorkoutBriefingBoard), findsNothing);
        if (scenario == 'manual' || scenario == 'remote-manual') {
          await tester.tap(find.text('종료하기'));
          // The live timer keeps scheduling frames behind the dialog. Wait only
          // for the route animation; waiting for total idleness cannot finish.
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          expect(find.text('수업을 종료할까요?'), findsOneWidget);
          await tester.tap(find.text('수업 종료'));
          if (scenario == 'remote-manual') {
            await tester.pump();
            await tester.pump();
            expect(complete.calls, 1);
            complete.pending.complete(true);
          }
        } else if (scenario == 'natural') {
          // Player deadlines intentionally use wall time (background recovery).
          // Advancing the widget's fake frame clock alone cannot expire them.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1200)),
          );
          await tester.pump(const Duration(milliseconds: 100));
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

class _Complete extends PlaybackActionController {
  _Complete(this.onComplete);
  final void Function() onComplete;
  final pending = Completer<bool>();
  int calls = 0;
  @override
  Future<bool> complete() {
    calls++;
    onComplete();
    return pending.future;
  }
}
