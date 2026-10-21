import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/display_playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// STA-195: real checkpoint, lifecycle and player logic; only SDK transports,
// recovery I/O, wall clock and native audio output are substituted.
// This deliberately does not override displayPlaybackSessionProvider.
void main() {
  for (final displayMode in [true, false]) {
    testWidgets(
      'offline ${displayMode ? 'display hides notices' : 'controller keeps its connection message'}',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = _Harness();
        await h.initialize(tester);
        h.container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: MaterialApp(
              home: WorkoutPlayerScreen(
                workoutId: h.workout.id,
                startModule: 0,
                sessionId: 'class',
                displayMode: displayMode,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        h.connection.add(false);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
        expect(find.text('오프라인 · 로컬 재생'), findsNothing);
        expect(
          find.text('컨트롤러의 서버 연결이 끊겼습니다. 연결 복구 후 수업 상태를 확인해 주세요.'),
          displayMode ? findsNothing : findsOneWidget,
        );
        if (displayMode) expect(find.byType(Chip), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await h.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'checkpoint survives raw invalidation and transient errors in one owner scope',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.initialize(tester);
      final first = h.current;
      h.container.invalidate(activePlaybackSessionProvider);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.container.read(activePlaybackSessionProvider).isLoading, isTrue);
      expect(h.current, same(first));
      h.sessions.addError(
        FirebaseException(plugin: 'firebase_database', code: 'unavailable'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.container.read(activePlaybackSessionProvider).hasError, isTrue);
      expect(h.current, same(first));
      h.recovery.update(
        AsyncError(TimeoutException('server confirmation'), StackTrace.current),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current, same(first));
    },
  );

  for (final boundary in ['null', 'loading', 'error', 'other-owner']) {
    testWidgets('checkpoint is discarded when owner becomes $boundary', (
      tester,
    ) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.initialize(tester);
      expect(h.current, isNotNull);
      switch (boundary) {
        case 'null':
          h.owners.add(null);
        case 'loading':
          h.container.invalidate(accountOwnerIdProvider);
        case 'error':
          h.owners.addError(StateError('owner unresolved'));
        case 'other-owner':
          h.owners.add('other-owner');
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current, isNull);
      // Delayed traffic from the previous owner cannot restore the old class.
      h.sessions.add(h.running(revision: 8));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current, isNull);
    });
  }

  for (final source in ['raw', 'recovery']) {
    for (final code in ['permission-denied', 'unauthenticated']) {
      testWidgets('$source $code discards the rendering checkpoint', (
        tester,
      ) async {
        final h = _Harness();
        addTearDown(h.dispose);
        await h.initialize(tester);
        final error = FirebaseException(
          plugin: 'firebase_database',
          code: code,
        );
        if (source == 'raw') {
          h.sessions.addError(error);
        } else {
          h.recovery.update(AsyncError(error, StackTrace.current));
        }
        await tester.pump(const Duration(milliseconds: 1));
        expect(h.current, isNull);
        // A subsequent loading state must not resurrect the revoked checkpoint.
        h.container.invalidate(activePlaybackSessionProvider);
        await tester.pump(const Duration(milliseconds: 1));
        expect(h.current, isNull);
        h.sessions.add(h.running(revision: 2));
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          h.current,
          isNull,
          reason: 'Data alone cannot reopen rejected authorization',
        );
        h.recovery.update(const AsyncLoading());
        h.recovery.update(const AsyncData(null));
        await tester.pump(const Duration(milliseconds: 1));
        expect(h.current?.revision, 2);
      });
    }
  }

  for (final replacement in [
    'completed',
    'null',
    'paused',
    'new-session',
    'new-targets',
    'foreign-owner',
  ]) {
    testWidgets('a fresh $replacement result supersedes retained playback', (
      tester,
    ) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.initialize(tester);
      h.container.invalidate(activePlaybackSessionProvider);
      await tester.pump(const Duration(milliseconds: 1));
      final next = switch (replacement) {
        'completed' =>
          h.running(revision: 2).copyWith(status: PlaybackStatus.completed),
        'null' => null,
        'paused' =>
          h
              .running(revision: 2)
              .copyWith(status: PlaybackStatus.paused, remainingMs: 4000),
        'new-session' => h.running(revision: 1).copyWith(id: 'next-class'),
        'new-targets' =>
          h.running(revision: 2).copyWith(targetDeviceIds: ['other-tv']),
        _ => h.running(revision: 2).copyWith(ownerId: 'other-owner'),
      };
      h.sessions.add(next);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current, replacement == 'foreign-owner' ? isNull : equals(next));
      if (replacement == 'new-targets') {
        expect(h.current!.targetDeviceIds, ['other-tv']);
      }
      if (replacement == 'paused') {
        expect(h.current!.status, PlaybackStatus.paused);
      }
    });
  }

  for (final boundary in ['null', 'other-session', 'permission-denied']) {
    testWidgets(
      'retained player cannot start a local preview after $boundary',
      (tester) async {
        final h = _Harness();
        addTearDown(h.dispose);
        await h.initialize(tester);
        h.container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
        final provider = playerControllerProvider(
          h.workout,
          sessionId: 'class',
          canControl: false,
        );
        h.container.listen(provider, (_, _) {});
        await tester.pump(const Duration(milliseconds: 1));
        await h.advance(tester, 10);
        expect(h.container.read(provider).index, 1);
        final cues = h.audio.starts.length;
        if (boundary == 'permission-denied') {
          h.sessions.addError(
            FirebaseException(plugin: 'firebase_database', code: boundary),
          );
        } else {
          h.sessions.add(
            boundary == 'null' ? null : h.running().copyWith(id: 'other'),
          );
        }
        await tester.pump(const Duration(milliseconds: 1));
        final stopped = h.container.read(provider);
        expect(stopped.isPaused, isTrue);
        expect(stopped.countdownMs, 0);
        await h.advance(tester, 30);
        expect(h.container.read(provider).remainingMs, stopped.remainingMs);
        expect(h.audio.starts, hasLength(cues));
        await h.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  testWidgets(
    'foreground TV keeps real ticker, interval transitions and cues during disconnect and recovery',
    (tester) async {
      final h = _Harness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await h.dispose();
      });
      await h.mountTv(tester);
      h.recovery.finish();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isTrue);
      expect(h.player!.remainingMs, 10000);
      expect(h.audio.starts, [WorkoutSound.classicBeep]);
      h.audio.enabledChanges.clear();
      final initialRecoveries = h.recovery.calls;
      h.connection.add(false);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isTrue);
      expect(h.recovery.calls, initialRecoveries);
      h.container.invalidate(activePlaybackSessionProvider);
      await tester.pump(const Duration(milliseconds: 1));
      await h.advance(tester, 2);
      expect(h.player!.remainingMs, 8000);
      h.sessions.addError(
        FirebaseException(plugin: 'firebase_database', code: 'unavailable'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await h.advance(tester, 5);
      expect(h.player!.remainingMs, 3000);
      expect(h.audio.ticks, [WorkoutSound.videoBeep]);
      await h.advance(tester, 3);
      expect(h.player!.index, 1);
      expect(h.player!.remainingMs, 5000);
      expect(h.player!.steps[h.player!.index].isRest, isTrue);
      expect(h.audio.starts, [
        WorkoutSound.classicBeep,
        WorkoutSound.gentleBeep,
      ]);

      h.connection.add(true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.recovery.calls, initialRecoveries + 1);
      expect(
        h.container.read(playbackRecoveryControllerProvider).isLoading,
        isTrue,
      );
      expect(h.visible, isTrue);
      await h.advance(tester, 5);
      expect(h.player!.index, 2);
      expect(h.player!.remainingMs, 10000);
      expect(h.audio.starts, [
        WorkoutSound.classicBeep,
        WorkoutSound.gentleBeep,
        WorkoutSound.classicBeep,
      ]);
      expect(h.audio.enabledChanges, isNot(contains(false)));
      final cues = h.audio.starts.length;
      // Same revision after reconnection uses the original anchor, never restarts.
      h.sessions.add(h.running());
      h.recovery.finish();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isTrue);
      expect(h.player!.index, 2);
      expect(h.player!.remainingMs, 10000);
      expect(h.audio.starts, hasLength(cues));
      final diagnostic = h.container
          .read(errorReporterProvider)
          .capture(
            StateError('fixture diagnostic'),
            StackTrace.current,
            action: 'test.continuity',
          );
      final confirmation = diagnostic.breadcrumbs.lastWhere(
        (entry) =>
            entry['action'] == 'display.recovery.transport_connected.finished',
      );
      expect(confirmation['status'], 'confirmed');
      expect(confirmation['elapsedMs'], isNonNegative);
      expect(
        confirmation['recovering'],
        isFalse,
        reason: 'The trace distinguishes background confirmation from blocked playback',
      );
      expect(
        h.container.exists(playbackActionControllerProvider),
        isFalse,
        reason: 'Display continuity never issues shared pause/start/complete commands',
      );
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'cold and standby TV still blocks until confirmation and while reconnecting',
    (tester) async {
      final h = _Harness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await h.dispose();
      });
      await h.mountTv(tester, startSession: false);
      expect(h.visible, isFalse);
      expect(h.audio.enabledChanges, isNot(contains(true)));
      expect(find.text('blocked'), findsOneWidget);
      h.recovery.finish();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isTrue);
      h.connection.add(false);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isFalse);
      expect(h.audio.enabledChanges.last, isFalse);
    },
  );

  testWidgets(
    'background remains a hard boundary even with a retained active class',
    (tester) async {
      final h = _Harness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await h.dispose();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      await h.mountTv(tester);
      h.recovery.finish();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isFalse);
      expect(h.audio.enabledChanges.last, isFalse);
      final cues = h.audio.starts.length;
      await h.advance(tester, 15);
      expect(h.audio.starts, hasLength(cues));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isFalse);
      h.recovery.finish();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.visible, isTrue);
      expect(h.player!.index, 2);
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  for (final source in ['raw', 'recovery']) {
    for (final code in ['permission-denied', 'unauthenticated']) {
      testWidgets('active TV cannot continue after $source $code', (
        tester,
      ) async {
        final h = _Harness();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await h.dispose();
        });
        await h.mountTv(tester);
        h.recovery.finish();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        final error = FirebaseException(
          plugin: 'firebase_database',
          code: code,
        );
        if (source == 'raw') {
          h.sessions.addError(error);
        } else {
          h.recovery.update(AsyncError(error, StackTrace.current));
        }
        await tester.pump(const Duration(milliseconds: 1));
        expect(h.current, isNull);
        expect(h.visible, isFalse);
        expect(h.audio.enabledChanges.last, isFalse);
        final calls = h.recovery.calls;
        await tester.pump(const Duration(seconds: 40));
        expect(
          h.recovery.calls,
          calls,
          reason: 'Auth rejection must not start a network retry loop',
        );
      });
    }
  }

  testWidgets(
    'real Display ACK effect never acknowledges its retained rendering value',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _Harness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await h.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(home: DisplayModeScreen()),
        ),
      );
      await h.initialize(tester);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.acks.values, [('tv', 'class', 1)]);
      expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
      h.acks.values.clear();
      h.container.invalidate(activePlaybackSessionProvider);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current?.id, 'class');
      expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
      expect(h.acks.values, isEmpty);
      h.sessions.addError(
        FirebaseException(plugin: 'firebase_database', code: 'unavailable'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.acks.values, isEmpty);
      h.recovery.update(const AsyncLoading());
      h.sessions.add(h.running(revision: 2));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        h.acks.values,
        isEmpty,
        reason: 'Fresh data alone does not complete an unresolved recovery',
      );
      h.recovery.update(const AsyncData(null));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.acks.values, [('tv', 'class', 2)]);
      h.acks.values.clear();
      h.sessions.add(
        h.running(revision: 3).copyWith(targetDeviceIds: ['other-tv']),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      expect(
        h.acks.values,
        isEmpty,
        reason: 'A freshly excluded TV must stop rendering and acknowledging',
      );
      h.sessions.add(null);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      expect(h.current, isNull);
      expect(h.acks.values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'offline class crosses every slide and stays completed after remount and stale recovery',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _Harness(
        modules: [
          for (var i = 0; i < 3; i++)
            WorkoutModule.empty('slide-$i')
                .copyWith(workSeconds: 10, restSeconds: 5, sets: 2, beep: true),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await h.dispose();
      });
      Widget display() => UncontrolledProviderScope(
        container: h.container,
        child: const MaterialApp(home: DisplayModeScreen()),
      );
      await tester.pumpWidget(display());
      await h.initialize(tester);
      h.container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      await tester.pump(const Duration(milliseconds: 1));
      h.acks.values.clear();
      h.connection.add(false);
      h.container.invalidate(activePlaybackSessionProvider);
      h.recovery.update(const AsyncLoading());
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('오프라인 · 로컬 재생'), findsNothing);
      final player = playerControllerProvider(
        h.workout,
        sessionId: 'class',
        canControl: false,
      );
      final observedModules = <int>{};
      final subscription = h.container.listen(player, (_, value) {
        if (value.index < value.steps.length) {
          observedModules.add(value.steps[value.index].moduleIndex);
        }
      }, fireImmediately: true);
      for (var second = 0; second < 100; second++) {
        await h.advance(tester, 1);
      }
      expect(observedModules, containsAll([0, 1, 2]));
      expect(h.current!.status, PlaybackStatus.completed);
      expect(
        h.container
            .read(displayPlaybackSessionProvider.notifier)
            .completedLocally('class'),
        isTrue,
      );
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      expect(h.acks.values, isEmpty);
      subscription.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(display());
      // Even a clock correction and an old cached playing anchor cannot revive it.
      h.now = h.initialNow;
      h.sessions.add(h.running(revision: 1));
      h.recovery.update(const AsyncData(null));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current!.status, PlaybackStatus.completed);
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      expect(h.acks.values, isEmpty);
      h.sessions.add(h.running().copyWith(id: 'new-class'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.current!.id, 'new-class');
      expect(h.current!.status, PlaybackStatus.playing);
      expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await h.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  for (final mode in ['paused', 'forTime']) {
    testWidgets(
      'offline $mode remains at its manual boundary without a local completion',
      (tester) async {
        final h = _Harness(
          modules: [
            WorkoutModule.empty('manual').copyWith(
              timingVersion: 3,
              intervalBlocks: [],
              workSeconds: 10,
              restSeconds: 0,
              sets: 1,
              timerMode: mode == 'forTime'
                  ? WorkoutTimerMode.forTime
                  : WorkoutTimerMode.interval,
            ),
          ],
        );
        addTearDown(h.dispose);
        await h.initialize(tester);
        h.container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
        if (mode == 'paused') {
          h.sessions.add(h.running().copyWith(status: PlaybackStatus.paused));
          await tester.pump();
        }
        final provider = playerControllerProvider(
          h.workout,
          sessionId: 'class',
          canControl: false,
        );
        final listener = h.container.listen(provider, (_, _) {});
        h.connection.add(false);
        h.recovery.update(const AsyncLoading());
        await tester.pump();
        await h.advance(tester, 3600);
        expect(h.container.read(provider).isPaused, isTrue);
        expect(h.container.read(provider).index, 0);
        expect(h.current!.status, isNot(PlaybackStatus.completed));
        expect(
          h.container
              .read(displayPlaybackSessionProvider.notifier)
              .completedLocally('class'),
          isFalse,
        );
        listener.close();
        await h.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

class _Harness {
  _Harness({List<WorkoutModule>? modules}) {
    initialNow = now;
    workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'owner',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ).copyWith(
          countdownSeconds: 0,
          workStartSound: WorkoutSound.classicBeep,
          restStartSound: WorkoutSound.gentleBeep,
          countdownSound: WorkoutSound.videoBeep,
          modules:
              modules ??
              [
                WorkoutModule.empty('module').copyWith(
                  workSeconds: 10,
                  restSeconds: 5,
                  sets: 2,
                  beep: true,
                ),
              ],
        );
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        accountOwnerIdProvider.overrideWith((_) => owners.stream),
        activePlaybackSessionProvider.overrideWith((_) => sessions.stream),
        playbackConnectionProvider.overrideWith((_) => connection.stream),
        playbackRecoveryControllerProvider.overrideWith(() => recovery),
        tvPlaybackVisibleProvider.overrideWith(
          () => TvPlaybackVisible(initiallyVisible: false),
        ),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        playerClockProvider.overrideWith(
          (_) =>
              () => now,
        ),
        beepPlayerProvider.overrideWithValue(audio),
        androidTvProvider.overrideWith((_) async => false),
        deviceIdProvider.overrideWith((_) async => 'tv'),
        deviceModeControllerProvider.overrideWith(_Mode.new),
        devicePairingControllerProvider.overrideWith(_Pair.new),
        devicePairingActionsProvider.overrideWithValue(acks),
        displayDevicesProvider.overrideWith(
          (_) => Stream.value([
            const DisplayDevice(
              id: 'tv',
              name: 'TV',
              zoneId: 'main',
              zoneName: 'Main',
              online: true,
              lastSeenAtMs: 0,
              currentSessionId: null,
              acknowledgedRevision: 0,
              paired: true,
            ),
          ]),
        ),
        effectiveBrandTemplateProvider.overrideWith(
          (_) => Stream.value(BrandTemplate.initial()),
        ),
        audienceBrandingProvider.overrideWith((_) => null),
        workoutSchedulesProvider.overrideWith((_) => Stream.value([])),
      ],
    );
    container.listen(displayPlaybackSessionProvider, (_, _) {});
    container.listen(playbackConnectionProvider, (_, _) {});
  }
  final owners = StreamController<String?>.broadcast();
  final sessions = StreamController<PlaybackSession?>.broadcast();
  final connection = StreamController<bool>.broadcast();
  final audio = _Audio();
  final recovery = _Recovery();
  final acks = _Acks();
  late final ProviderContainer container;
  DateTime now = DateTime(2026, 10, 19, 18);
  late final DateTime initialNow;
  late final Workout workout;
  PlayerState? player;
  PlaybackSession? get current =>
      container.read(displayPlaybackSessionProvider);
  bool get visible => container.read(tvPlaybackVisibleProvider);
  PlaybackSession running({int revision = 1}) => PlaybackSession(
    id: 'class',
    ownerId: 'owner',
    zoneId: 'main',
    targetDeviceIds: ['tv'],
    workout: workout,
    status: PlaybackStatus.playing,
    stepIndex: 0,
    remainingMs: 10000,
    anchorServerMs: initialNow.millisecondsSinceEpoch,
    revision: revision,
    updatedByDeviceId: 'controller',
  );
  Future<void> initialize(
    WidgetTester tester, {
    bool startSession = true,
  }) async {
    owners.add('owner');
    await tester.pump(const Duration(milliseconds: 1));
    sessions.add(startSession ? running() : null);
    connection.add(true);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> mountTv(WidgetTester tester, {bool startSession = true}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TvPlaybackLifecycle(
            isTv: true,
            child: Consumer(
              builder: (_, ref, _) {
                final session = ref.watch(displayPlaybackSessionProvider);
                if (!ref.watch(tvPlaybackVisibleProvider) ||
                    session == null ||
                    session.status == PlaybackStatus.completed) {
                  return const Text('blocked');
                }
                return Consumer(
                  builder: (_, ref, _) {
                    player = ref.watch(
                      playerControllerProvider(
                        session.workout,
                        sessionId: session.id,
                        canControl: false,
                      ),
                    );
                    return Text('${player!.index}/${player!.remainingMs}');
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await initialize(tester, startSession: startSession);
  }

  Future<void> advance(WidgetTester tester, int seconds) async {
    now = now.add(Duration(seconds: seconds));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1));
  }

  bool disposed = false;
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    recovery.finish();
    container.dispose();
    await owners.close();
    await sessions.close();
    await connection.close();
  }
}

class _Recovery extends PlaybackRecoveryController {
  int calls = 0;
  Completer<void>? pending;
  @override
  AsyncValue<void> build() => const AsyncData(null);
  void update(AsyncValue<void> next) => state = next;
  @override
  Future<void> recover({bool restartTransport = true}) async {
    calls++;
    state = const AsyncLoading();
    pending = Completer<void>();
    await pending!.future;
  }

  void finish() {
    if (pending == null || pending!.isCompleted) return;
    state = const AsyncData(null);
    pending!.complete();
  }

  @override
  void recordDisplayVisibility({
    required bool visible,
    bool shutdown = false,
  }) {}
}

class _Audio implements BeepPlayer {
  bool enabled = true;
  final enabledChanges = <bool>[];
  final starts = <WorkoutSound>[];
  final ticks = <WorkoutSound>[];
  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    enabledChanges.add(value);
  }

  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async {
    if (enabled) starts.add(sound);
  }

  @override
  Future<void> playCountdown(WorkoutSound sound, double volume) async {
    if (enabled) ticks.add(sound);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.display;
}

class _Pair extends DevicePairingController {
  @override
  Future<void> refresh() async {
    state = AsyncData(await build());
  }

  @override
  Future<DevicePairing> build() async => const DevicePairing(
    code: '123456',
    deviceId: 'tv',
    expiresAtMs: 9999999999999,
  );
}

class _Acks implements DevicePairingActions {
  final values = <(String, String, int)>[];
  @override
  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) async {
    values.add((deviceId, sessionId, revision));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
