import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/first_class_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/starter_workouts_screen.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

const author = WorkoutAuthor(id: 'owner', displayName: 'Coach', photoUrl: null);
final workout = StarterWorkout.basics.create(author);
final session = PlaybackSessionModel.fromWorkout(
  id: 'session',
  ownerId: 'owner',
  zoneId: 'main',
  targetDeviceIds: ['tv'],
  workout: workout,
  stepIndex: 0,
  durationMs: 60000,
  deviceId: 'phone',
).toEntity();
DisplayDevice device({
  String id = 'tv',
  String? sessionId = 'session',
  int revision = 1,
  bool online = true,
  String mode = 'auto',
}) => DisplayDevice(
  id: id,
  name: 'TV',
  zoneId: 'main',
  zoneName: 'main',
  online: online,
  lastSeenAtMs: 0,
  currentSessionId: sessionId,
  acknowledgedRevision: revision,
  paired: true,
  displayState: mode,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('progress survives recreation, isolated by user and center', () async {
    FirstClassRepositoryImpl repository() => FirstClassRepositoryImpl(
      SharedPreferencesAsync(),
      sendEvent: (_, _, _) async {},
    );
    final value = (await repository().load('u', 'c')).copyWith(
      dismissed: true,
      savedWorkoutId: 'saved',
      verifiedDeviceId: 'tv',
    );
    await repository().save('u', 'c', value);
    expect(await repository().load('u', 'c'), value);
    expect((await repository().load('u2', 'c')).savedWorkoutId, isNull);
    expect((await repository().load('u', 'c2')).dismissed, isFalse);
    expect(
      firstClassScopeKey('a-b', 'c'),
      isNot(firstClassScopeKey('a', 'b-c')),
    );
  });

  test('only the selected TV acknowledging this playing revision completes playback', () {
    expect(hasFirstPlaybackAck(session, [device()]), isTrue);
    for (final d in [
      device(id: 'other'),
      device(sessionId: 'old'),
      device(revision: 0),
      device(online: false),
      device(mode: 'standby'),
    ]) {
      expect(hasFirstPlaybackAck(session, [d]), isFalse);
    }
    expect(
      hasFirstPlaybackAck(session.copyWith(targetDeviceIds: []), [device()]),
      isFalse,
    );
    expect(
      hasFirstPlaybackAck(session.copyWith(status: PlaybackStatus.paused), [
        device(),
      ]),
      isFalse,
    );
    expect(
      hasFirstPlaybackAck(session.copyWith(briefing: true), [device()]),
      isFalse,
    );
  });

  test(
    'controller records server save, deduplicates steps and waits for TV ACK',
    () async {
      final events = <String, Map<String, Object?>>{};
      final devices = StreamController<List<DisplayDevice>>.broadcast();
      final active = StreamController<PlaybackSession?>.broadcast();
      final repository = FirstClassRepositoryImpl(
        SharedPreferencesAsync(),
        sendEvent: (_, id, value) async {
          events[id] = value;
        },
      );
      FirstClassScope scope = (
        userId: 'owner',
        centerId: 'center',
        centerReady: true,
      );
      final container = ProviderContainer(
        overrides: [
          firstClassScopeProvider.overrideWith((_) async => scope),
          firstClassRepositoryProvider.overrideWith((_) => repository),
          displayDevicesProvider.overrideWith((_) => devices.stream),
          activePlaybackSessionProvider.overrideWith((_) => active.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await devices.close();
        await active.close();
      });
      final subscription = container.listen(
        firstClassControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(firstClassControllerProvider.future);
      final controller = container.read(firstClassControllerProvider.notifier);
      expect(
        container
            .read(firstClassControllerProvider)
            .value!
            .done(FirstClassStep.workout),
        isFalse,
      );
      await Future.wait([
        controller.enter(FirstClassStep.workout),
        controller.enter(FirstClassStep.workout),
      ]);
      await controller.saved(workout.id, ownerId: 'owner');
      active.add(session);
      devices.add([device(sessionId: 'old')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(firstClassControllerProvider).value!.playedSessionId,
        isNull,
      );
      devices.add([device()]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(firstClassControllerProvider).value!.complete,
        isTrue,
      );
      expect(
        events.values
            .where((e) => e['type'] == 'onboarding_workout_entered')
            .length,
        1,
      );
      expect(
        events.values.every(
          (e) => !e.containsKey('workoutName') && !e.containsKey('text'),
        ),
        isTrue,
      );
      await controller.dismiss(true);
      container.invalidate(firstClassControllerProvider);
      expect(
        (await container.read(firstClassControllerProvider.future))!.dismissed,
        isTrue,
      );
      scope = (
        userId: 'owner',
        centerId: 'different-center',
        centerReady: true,
      );
      container.invalidate(firstClassScopeProvider);
      final switched = await container.read(
        firstClassControllerProvider.future,
      );
      expect(switched!.savedWorkoutId, isNull);
      expect(switched.dismissed, isFalse);
      await controller.saved('foreign-save', ownerId: 'other-user');
      expect(
        container.read(firstClassControllerProvider).value!.savedWorkoutId,
        isNull,
      );
      scope = (userId: 'owner', centerId: 'center', centerReady: true);
      container.invalidate(firstClassScopeProvider);
      expect(
        (await container.read(firstClassControllerProvider.future))!.dismissed,
        isTrue,
      );
    },
  );

  test('starter pack uses neutral editable valid slides and stable IDs', () {
    for (final starter in StarterWorkout.values) {
      final draft = starter.create(author);
      expect(draft.id, starter.create(author).id);
      expect(draft.author, author);
      expect(draft.brandL, isEmpty);
      expect(draft.modules, hasLength(3));
      for (final slide in draft.modules) {
        expect(slideDesignError(slide), isNull);
        expect(timingValidationError(slide), isNull);
        expect(slide.designTemplate, startsWith('studio-'));
        expect(slide.designStyle?.originalTemplate, isNull);
      }
    }
  });

  test('sample playback stays visible as events but is excluded from real class metrics', () {
    final events = ['starter_basics', 'real-class']
        .map(
          (id) => OperationEvent(
            id: id,
            type: 'playback_started',
            occurredAtMs: DateTime.now().millisecondsSinceEpoch,
            workoutId: id,
            workoutName: id,
            deviceId: null,
            scheduled: false,
            scheduledAtMs: null,
          ),
        )
        .toList();
    final report = buildOperationsReport(events);
    expect(report.todayPlaybackCount, 1);
    expect(report.mostPlayedWorkoutName, 'real-class');
  });

  for (final size in [const Size(320, 568), const Size(834, 1194)]) {
    testWidgets('first class and starter previews fit $size at large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstClassScopeProvider.overrideWith(
              (_) async => (userId: 'owner', centerId: 'c', centerReady: true),
            ),
            firstClassRepositoryProvider.overrideWith(
              (_) => FirstClassRepositoryImpl(
                SharedPreferencesAsync(),
                sendEvent: (_, _, _) async {},
              ),
            ),
            displayDevicesProvider.overrideWith((_) => Stream.value([])),
            activePlaybackSessionProvider.overrideWith(
              (_) => Stream.value(null),
            ),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const FirstClassScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/4 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('starter'),
          child: MaterialApp(
            theme: XonTheme.light,
            home: const StarterWorkoutsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('예시로 첫 수업을 준비하세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
