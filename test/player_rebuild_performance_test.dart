import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets(
    'millisecond ticks reuse the slide and timer text while gauge updates',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workout =
          Workout.empty(
            'w',
            const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
          ).copyWith(
            modules: [
              WorkoutModule.empty('m').copyWith(name: 'Squat', beep: false),
            ],
          );
      final session = PlaybackSessionModel.fromWorkout(
        id: 's',
        ownerId: 'u',
        zoneId: 'main',
        targetDeviceIds: [],
        workout: workout,
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'd',
      ).toEntity();
      final provider = playerControllerProvider(
        workout,
        startModule: 0,
        sessionId: 's',
        canControl: false,
      );
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(session),
          ),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
          androidTvProvider.overrideWith((ref) async => true),
          provider.overrideWith(_ControlledPlayer.new),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WorkoutPlayerScreen(
              workoutId: 'w',
              startModule: 0,
              sessionId: 's',
              displayMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.widget<WorkoutSlideCanvas>(
        find.byType(WorkoutSlideCanvas),
      );
      final textBefore = tester.widget<Text>(
        find.byKey(const ValueKey('slide-time-text')),
      );
      final controller = container.read(provider.notifier) as _ControlledPlayer;
      for (var tick = 1; tick <= 9; tick++) {
        controller.tick(60000 - tick * 100);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          identical(
            tester.widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas)),
            before,
          ),
          isTrue,
        );
        expect(
          identical(
            tester.widget<Text>(find.byKey(const ValueKey('slide-time-text'))),
            textBefore,
          ),
          isTrue,
        );
      }
      controller.tick(59000);
      await tester.pump();
      expect(find.text('0:59'), findsOneWidget);
      expect(
        identical(
          tester.widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas)),
          before,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}

class _ControlledPlayer extends PlayerController {
  @override
  PlayerState build(
    Workout workout, {
    int startModule = 0,
    String? sessionId,
    bool canControl = true,
  }) => PlayerState(
    steps: buildPlayerSteps(workout),
    index: 0,
    remainingMs: 60000,
    isPaused: false,
  );
  void tick(int remainingMs) =>
      state = state.copyWith(remainingMs: remainingMs);
}
