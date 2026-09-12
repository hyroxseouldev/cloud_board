import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';

final workout =
    Workout.empty(
      'workout',
      const WorkoutAuthor(id: 'coach', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: 'ATHX Training : 14min × 3',
      brandL: 'XON DAY',
      brandR: 'XON TRAINING',
      modules: [
        WorkoutModule.empty('strength').copyWith(
          name: 'STRENGTH',
          workSeconds: 840,
          text: '0–7 MIN\n5RM BB Strict Press\n\n7–14 MIN\n5RM BB Deadlift',
          beep: false,
        ),
        WorkoutModule.empty('endurance').copyWith(
          name: 'ENDURANCE',
          workSeconds: 840,
          text: 'P1: 500m Run\nP2: Rowing\n\n파트너와 교대합니다.',
          beep: false,
        ),
        WorkoutModule.empty('metcon').copyWith(
          name: 'METCON',
          workSeconds: 840,
          text: '2 Rounds\n40/30 cal Ski-Erg\n40 DB Dual Snatch\n40 DB Box Step Up\n40 DB Push Press\n\nMax Plank',
          beep: false,
        ),
      ],
    );

PlaybackSession session() => PlaybackSessionModel.fromWorkout(
  id: 'session',
  ownerId: 'coach',
  zoneId: 'main',
  targetDeviceIds: ['tv-a', 'tv-b'],
  workout: workout,
  stepIndex: 0,
  durationMs: 840000,
  deviceId: 'phone',
  briefing: true,
).toEntity().copyWith(anchorServerMs: 100000);

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(800, 1280),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'shared timer styles, remaining sets and hidden rest fit $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = StreamController<PlaybackSession?>();
        final styled = workout.copyWith(
          modules: [
            workout.modules.first.copyWith(
              workSeconds: 90,
              restSeconds: 45,
              sets: 5,
              workGaugeColor: '#112233',
              workTextColor: '#445566',
              restGaugeColor: '#778899',
              restTextColor: '#AABBCC',
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            activePlaybackSessionProvider.overrideWith((ref) => source.stream),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            playbackConnectionProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            androidTvProvider.overrideWith((ref) async => true),
          ],
        );
        container.listen(activePlaybackSessionProvider, (_, _) {});
        final current = session().copyWith(
          workout: styled,
          briefing: false,
          remainingMs: 90000,
        );
        source.add(current);
        await tester.pump();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: WorkoutPlayerScreen(
                workoutId: workout.id,
                startModule: 0,
                sessionId: 'session',
                displayMode: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('5/5세트'), findsOneWidget);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .color,
          const Color(0xFF112233),
        );
        expect(
          tester.widget<Text>(find.text('1:30')).style!.color,
          const Color(0xFF445566),
        );
        expect(find.text('동기화됨'), findsNothing);
        source.add(
          current.copyWith(stepIndex: 1, remainingMs: 45000, revision: 2),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('4/5세트'), findsOneWidget);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .color,
          const Color(0xFF778899),
        );
        expect(
          tester.widget<Text>(find.text('0:45')).style!.color,
          const Color(0xFFAABBCC),
        );
        source.add(
          current.copyWith(
            stepIndex: 1,
            remainingMs: 45000,
            revision: 3,
            workout: styled.copyWith(
              modules: [styled.modules.single.copyWith(showTimerGauge: false)],
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('4/5세트'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('0:45')).style!.color,
          const Color(0xFFAABBCC),
        );
        source.add(
          current.copyWith(
            revision: 4,
            workout: styled.copyWith(
              modules: [styled.modules.single.copyWith(showTimerGauge: false)],
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('5/5세트'), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('1:30')).style!.color,
          const Color(0xFF445566),
        );
        source.add(
          current.copyWith(
            stepIndex: 1,
            remainingMs: 45000,
            revision: 5,
            workout: styled.copyWith(
              modules: [styled.modules.single.copyWith(showTimer: false)],
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('0:45'), findsNothing);
        expect(find.text('4/5세트'), findsOneWidget);
        source.add(
          current.copyWith(
            stepIndex: 1,
            remainingMs: 45000,
            revision: 6,
            workout: styled.copyWith(
              modules: [styled.modules.single.copyWith(showSets: false)],
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('0:45'), findsOneWidget);
        expect(find.text('4/5세트'), findsNothing);
        expect(find.text('다음: 2세트'), findsNothing);
        source.add(
          current.copyWith(
            stepIndex: 1,
            remainingMs: 45000,
            revision: 7,
            workout: styled.copyWith(
              modules: [
                styled.modules.single.copyWith(
                  showTimer: false,
                  showSets: false,
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('4/5세트'), findsNothing);
        expect(find.text('휴식'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        unawaited(source.close());
        await tester.pump();
      },
    );
  }
  testWidgets(
    'TV follows briefing, countdown, workout, completion and standby',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = StreamController<PlaybackSession?>();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith((ref) => source.stream),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
          androidTvProvider.overrideWith((ref) async => true),
          brandTemplateProvider.overrideWith(
            (ref) => Stream.value(BrandTemplate.initial()),
          ),
        ],
      );
      container.listen(serverTimeOffsetProvider, (_, _) {});
      container.listen(activePlaybackSessionProvider, (_, _) {});
      container.listen(playbackConnectionProvider, (_, _) {});
      container.listen(androidTvProvider, (_, _) {});
      source.add(session());
      await tester.pump();
      var returnedToStandby = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: WorkoutPlayerScreen(
              workoutId: workout.id,
              startModule: 0,
              sessionId: 'session',
              displayMode: true,
              onStandby: () => returnedToStandby = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(WorkoutBriefingBoard), findsNothing);
      expect(find.byType(StoreWelcomeBoard), findsOneWidget);

      final running = session().copyWith(
        briefing: false,
        status: PlaybackStatus.playing,
        startDelayMs: 3000,
        revision: 2,
        anchorServerMs: DateTime.now().millisecondsSinceEpoch,
      );
      source.add(running);
      await tester.pump();
      await tester.pump();
      expect(find.text('준비하세요'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      source.add(
        running.copyWith(
          revision: 3,
          anchorServerMs: DateTime.now().millisecondsSinceEpoch - 4000,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('준비하세요'), findsNothing);
      expect(find.text('STRENGTH'), findsOneWidget);

      source.add(
        running.copyWith(
          status: PlaybackStatus.completed,
          revision: 4,
          remainingMs: 0,
          anchorServerMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('WORKOUT DONE'), findsOneWidget);
      expect(returnedToStandby, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(returnedToStandby, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      unawaited(source.close());
      await tester.pump();
    },
  );

  test('briefing holds indefinitely without consuming workout time', () {
    final value = resolvePlaybackPosition(
      session(),
      buildPlayerSteps(workout),
      9999999,
    );
    expect(value, (index: 0, remainingMs: 840000, countdownMs: 0));
  });

  test(
    'all screens count down on server time before consuming workout time',
    () {
      final running = session().copyWith(
        briefing: false,
        status: PlaybackStatus.playing,
        startDelayMs: 3000,
      );
      final steps = buildPlayerSteps(workout);
      expect(resolvePlaybackPosition(running, steps, 101000), (
        index: 0,
        remainingMs: 840000,
        countdownMs: 2000,
      ));
      expect(resolvePlaybackPosition(running, steps, 103000), (
        index: 0,
        remainingMs: 840000,
        countdownMs: 0,
      ));
      expect(resolvePlaybackPosition(running, steps, 108000), (
        index: 0,
        remainingMs: 835000,
        countdownMs: 0,
      ));
    },
  );

  test(
    'reconnected display catches up across slides and recognizes completion',
    () {
      final running = session().copyWith(
        briefing: false,
        status: PlaybackStatus.playing,
        startDelayMs: 3000,
      );
      final steps = buildPlayerSteps(workout);
      expect(resolvePlaybackPosition(running, steps, 943000), (
        index: 1,
        remainingMs: 840000,
        countdownMs: 0,
      ));
      expect(resolvePlaybackPosition(running, steps, 1793000), (
        index: 2,
        remainingMs: 830000,
        countdownMs: 0,
      ));
      expect(resolvePlaybackPosition(running, steps, 2623000), (
        index: 3,
        remainingMs: 0,
        countdownMs: 0,
      ));
    },
  );

  test(
    'legacy snapshots still play and new briefing fields survive serialization',
    () {
      final model = PlaybackSessionModel.fromWorkout(
        id: 's',
        ownerId: 'coach',
        zoneId: 'main',
        targetDeviceIds: [],
        workout: workout,
        stepIndex: 0,
        durationMs: 840000,
        deviceId: 'phone',
      );
      final legacy = model.toJson()
        ..remove('briefing')
        ..remove('startDelayMs');
      expect(
        PlaybackSessionModel.fromJson(legacy).toEntity().briefing,
        isFalse,
      );
      final updated = model.toJson()
        ..['briefing'] = true
        ..['startDelayMs'] = 3000;
      final restored = PlaybackSessionModel.fromJson(updated).toEntity();
      expect(restored.briefing, isTrue);
      expect(restored.startDelayMs, 3000);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(1280, 720),
  ]) {
    testWidgets('briefing fits $size and coach explicitly starts the class', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutBriefingBoard(
            workout: workout,
            displayMode: size.width > size.height,
            onStart: () => started = true,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(workout.name), findsOneWidget);
      expect(started, isFalse);
      if (size.width < size.height) {
        await tester.tap(find.text('수업 시작 · 3초 카운트다운'));
        expect(started, isTrue);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('welcome keeps store identity and next class visible offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoreWelcomeBoard(
          brand: BrandTemplate.initial().copyWith(storeName: 'XON TRAINING'),
          now: DateTime(2026, 9, 9, 10, 30),
          nextClass: '11:00 · ATHX',
          connected: false,
        ),
      ),
    );
    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('NEXT  11:00 · ATHX'), findsOneWidget);
    expect(find.text('오프라인 · 저장된 화면'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
