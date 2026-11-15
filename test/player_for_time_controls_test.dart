// Real player screen/controller with local workout data and no Firebase/TV.
import 'dart:convert';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/ui_layout_evidence.dart';

void main() {
  for (final cap in [0, 60]) {
    testWidgets(
      'For Time $cap keeps local controls without manual completion',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
        await loadLayoutFonts(tester);
        final bytes = await rootBundle.load(
          'assets/branding/soft_rhythm_mark.png',
        );
        final image =
            'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
        final workout =
            Workout.empty(
              'for-time-fixture',
              const WorkoutAuthor(
                id: 'fixture',
                displayName: 'Fixture',
                photoUrl: null,
              ),
            ).copyWith(
              name: 'For Time 로컬 수업',
              countdownSeconds: 0,
              soundVolume: 0,
              modules: [
                createContinuousTimer(
                  WorkoutModule.empty('for-time').copyWith(
                    name: 'For Time 운동',
                    imageSource: image,
                    beep: false,
                  ),
                  mode: WorkoutTimerMode.forTime,
                  seconds: cap,
                  direction: TimerDirection.up,
                ),
                WorkoutModule.empty('next')
                    .copyWith(name: '다음 운동', beep: false),
              ],
            );
        var now = DateTime(2026, 11, 15, 12);
        final container = ProviderContainer(
          overrides: [
            localPlaybackWorkoutProvider(workout.id)
                .overrideWith((_) async => workout),
            activePlaybackSessionProvider.overrideWith(
              (_) => Stream.value(null),
            ),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
            playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
            androidTvProvider.overrideWith((_) async => false),
            beepPlayerProvider.overrideWithValue(_SilentBeep()),
            playerClockProvider.overrideWith(
              (_) =>
                  () => now,
            ),
          ],
        );
        final provider = playerControllerProvider(workout);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: const ValueKey('for-time-capture'),
              child: MaterialApp(
                theme: XonTheme.light,
                home: WorkoutPlayerScreen(
                  workoutId: workout.id,
                  startModule: 0,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();
        now = now.add(const Duration(seconds: 12));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(WorkoutControlPanel), findsOneWidget);
        expect(find.byKey(const ValueKey('finish-for-time')), findsNothing);
        expect(find.widgetWithText(FilledButton, '운동 완료'), findsNothing);
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(WorkoutControlTimeline), findsNWidgets(2));
        expect(find.byTooltip('이전 운동'), findsOneWidget);
        expect(find.byTooltip('다음 운동'), findsOneWidget);
        expect(find.text('종료하기'), findsOneWidget);
        expect(container.read(provider).timerCompleted, isFalse);
        expect(container.read(provider).index, 0);
        await captureLayout(
          tester,
          find.byKey(const ValueKey('for-time-capture')),
          'controller-for-time-$cap',
        );
        final elapsed = container.read(provider).remainingMs;
        await tester.tap(find.byTooltip('일시정지'));
        await tester.pump();
        expect(container.read(provider).isPaused, isTrue);
        now = now.add(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 1));
        expect(container.read(provider).remainingMs, elapsed);
        await tester.tap(find.byTooltip('재생'));
        await tester.pump();
        expect(container.read(provider).isPaused, isFalse);
        await tester.tap(find.byTooltip('다음 운동'));
        await tester.pumpAndSettle();
        expect(
          container
              .read(provider)
              .steps[container.read(provider).index]
              .moduleIndex,
          1,
        );
        await tester.tap(find.byTooltip('이전 운동'));
        await tester.pumpAndSettle();
        expect(container.read(provider).index, 0);
        await tester.tap(find.text('터치 잠금'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<WorkoutControlPanel>(find.byType(WorkoutControlPanel))
              .locked,
          isTrue,
        );
        await tester.longPress(find.byKey(const ValueKey('unlock-controls')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<WorkoutControlPanel>(find.byType(WorkoutControlPanel))
              .locked,
          isFalse,
        );
        await tester.tap(find.text('종료하기'));
        await tester.pumpAndSettle();
        expect(find.text('수업을 종료할까요?'), findsOneWidget);
        await tester.tap(find.text('계속 진행'));
        await tester.pumpAndSettle();
        expect(container.read(provider).timerCompleted, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }
}

class _SilentBeep extends Fake implements BeepPlayer {
  @override
  Future<void> stop() async {}
}
