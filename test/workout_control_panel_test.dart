import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _workout =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: 'Workout Untitle #1',
      countdownSeconds: 0,
      modules: List.generate(
        3,
        (i) => WorkoutModule.empty('m$i').copyWith(
          name: '운동 ${i + 1}',
          beep: false,
          sets: 2,
          workSeconds: 60,
          restSeconds: 20,
        ),
      ),
    );

void main() {
  testWidgets(
    'slide selection skips all remaining sets and rejects invalid targets',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        ],
      );
      final provider = playerControllerProvider(_workout);
      final sub = container.listen(provider, (_, _) {});
      await tester.pump();
      final actions = container.read(provider.notifier);
      await actions.next();
      expect(
        container.read(provider).steps[container.read(provider).index].isRest,
        isTrue,
      );
      await actions.selectModule(1);
      var state = container.read(provider);
      expect(state.index, 3);
      expect(state.remainingMs, 60000);
      expect(state.isPaused, isFalse);
      await actions.selectModule(-1);
      await actions.selectModule(3);
      expect(container.read(provider).index, 3);
      await actions.selectModule(0);
      expect(container.read(provider).index, 0);
      sub.close();
      container.dispose();
    },
  );

  testWidgets(
    'remote slide selection uses first interval, blocks duplicate and rolls back failure',
    (tester) async {
      final session =
          PlaybackSessionModel.fromWorkout(
            id: 's',
            ownerId: 'u',
            zoneId: 'main',
            targetDeviceIds: [],
            workout: _workout,
            stepIndex: 0,
            durationMs: 60000,
            deviceId: 'd',
          ).toEntity().copyWith(
            anchorServerMs: DateTime.now().millisecondsSinceEpoch,
          );
      final fake = _RemoteActions();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(session),
          ),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          playbackActionControllerProvider.overrideWith(() => fake),
        ],
      );
      final provider = playerControllerProvider(_workout, sessionId: 's');
      final sub = container.listen(provider, (_, _) {});
      await tester.pump();
      final actions = container.read(provider.notifier);
      final before = container.read(provider);
      final pending = actions.selectModule(1);
      await actions.selectModule(2);
      expect(fake.calls, [(3, 60000)]);
      fake.result.complete(false);
      await pending;
      expect(container.read(provider).index, before.index);
      expect(container.read(provider).remainingMs, before.remainingMs);
      sub.close();
      container.dispose();
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(1194, 834),
  ]) {
    testWidgets(
      'swipe, external sync and failed command remain consistent at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var current = 0;
        var paused = false;
        var failed = false;
        var exits = 0;
        final selections = <int>[];
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: XonTheme.light,
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return WorkoutControlPanel(
                  title: _workout.name,
                  moduleCount: 3,
                  currentModule: current,
                  paused: paused,
                  busy: false,
                  onPrevious: () =>
                      setState(() => current = (current - 1).clamp(0, 2)),
                  onNext: () =>
                      setState(() => current = (current + 1).clamp(0, 2)),
                  onToggle: () => setState(() => paused = !paused),
                  onExit: () => exits++,
                  onSelectModule: (index) async {
                    selections.add(index);
                    if (!failed) setState(() => current = index);
                  },
                  previewBuilder: (_, index) => WorkoutSlidePreview(
                    module: _workout.modules[index],
                    isRest: false,
                  ),
                  timeline: WorkoutControlTimeline(
                    durations: const [140, 140, 140],
                    currentModule: current,
                    elapsedMs: 10000,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('일시정지'));
        await tester.pumpAndSettle();
        expect(paused, isTrue);
        final carousel = find.byKey(const ValueKey('workout-control-carousel'));
        await tester.ensureVisible(carousel);
        await tester.pumpAndSettle();
        await tester.drag(carousel, Offset(-size.width * .65, 0));
        await tester.pumpAndSettle();
        expect(current, 1);
        expect(selections, [1]);
        final pages = tester.widget<PageView>(carousel).controller!;
        expect(pages.page, closeTo(1, .01));
        rebuild(() => current = 2);
        await tester.pumpAndSettle();
        expect(pages.page, closeTo(2, .01));
        expect(selections, [
          1,
        ]); // State synchronization never sends another command.
        failed = true;
        await tester.drag(carousel, Offset(size.width * .65, 0));
        await tester.pumpAndSettle();
        expect(selections, [1, 1]);
        expect(current, 2);
        expect(pages.page, closeTo(2, .01));
        await tester.ensureVisible(find.text('종료하기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('종료하기'));
        expect(exits, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _RemoteActions extends PlaybackActionController {
  final result = Completer<bool>();
  final calls = <(int, int)>[];
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  @override
  Future<bool> seek({required int stepIndex, required int durationMs}) {
    calls.add((stepIndex, durationMs));
    return result.future;
  }
}
