import 'support/workout_catalog_fixture.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_edit_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
);
PlaybackSession session(PlaybackStatus status) => PlaybackSession(
  id: 'session',
  ownerId: 'u',
  zoneId: 'main',
  workout: workout,
  status: status,
  stepIndex: 0,
  remainingMs: 60000,
  anchorServerMs: 0,
  revision: 1,
  updatedByDeviceId: 'other-device',
);

void main() {
  test(
    'running, countdown and paused sessions lock the entire workout only',
    () {
      for (final status in [PlaybackStatus.playing, PlaybackStatus.paused]) {
        final value = session(status);
        expect(
          workoutEditBlockReason(AsyncData(value), 'w'),
          workoutPlayingEditMessage,
        );
        expect(
          workoutEditBlockReason(
            AsyncData(value.copyWith(startDelayMs: 3000)),
            'w',
          ),
          workoutPlayingEditMessage,
        );
        expect(workoutEditBlockReason(AsyncData(value), 'other'), isNull);
        expect(workoutEditBlockReason(AsyncData(value), 'new'), isNull);
      }
      expect(
        workoutEditBlockReason(
          AsyncData(session(PlaybackStatus.completed)),
          'w',
        ),
        isNull,
      );
      expect(workoutEditBlockReason(const AsyncData(null), 'w'), isNull);
      expect(workoutEditBlockReason(const AsyncLoading(), 'w'), isNotNull);
      expect(
        workoutEditBlockReason(
          AsyncError(StateError('offline'), StackTrace.empty),
          'w',
        ),
        isNotNull,
      );
    },
  );

  for (final path in ['/editor/w', '/editor/w/slides/m']) {
    testWidgets('direct entry $path stays locked until completion', (
      tester,
    ) async {
      final events = StreamController<PlaybackSession?>();
      addTearDown(events.close);
      final router = _router(path);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePlaybackSessionProvider.overrideWith((ref) => events.stream),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      events.add(session(PlaybackStatus.paused));
      await tester.pumpAndSettle();
      expect(find.text(workoutPlayingEditMessage), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      events.add(session(PlaybackStatus.completed));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(workoutPlayingEditMessage), findsNothing);
    });
  }

  testWidgets(
    'remote start freezes an open draft and closes root editing dialogs',
    (tester) async {
      final events = StreamController<PlaybackSession?>();
      addTearDown(events.close);
      final router = _router('/editor/w');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activePlaybackSessionProvider.overrideWith((ref) => events.stream),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      events.add(null);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '보존할 초안');
      await tester.tap(find.text('제목 대화상자'));
      await tester.pumpAndSettle();
      expect(find.text('제목 수정 중'), findsOneWidget);
      events.add(session(PlaybackStatus.playing));
      await tester.pumpAndSettle();
      expect(find.text('제목 수정 중'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('보존할 초안'), findsOneWidget);
    },
  );

  for (final status in [PlaybackStatus.playing, PlaybackStatus.paused]) {
    test('save and delete cannot reach the repository while $status', () async {
      final repo = _Repository();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(session(status)),
          ),
          saveWorkoutProvider.overrideWith((ref) async => SaveWorkout(repo)),
          deleteWorkoutProvider.overrideWith(
            (ref) async => DeleteWorkout(repo),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        workoutActionControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final actions = container.read(workoutActionControllerProvider.notifier);
      expect(await actions.save(workout), isNull);
      expect(await actions.delete(workout.id), isFalse);
      expect(repo.saves, isEmpty);
      expect(repo.deletes, isEmpty);
      expect(
        container.read(workoutActionControllerProvider).error.toString(),
        contains(workoutPlayingEditMessage),
      );
    });
  }

  test(
    'session starts while save dependency loads: recheck before writing',
    () async {
      final events = StreamController<PlaybackSession?>();
      addTearDown(events.close);
      final pending = Completer<SaveWorkout>();
      final repo = _Repository();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith((ref) => events.stream),
          saveWorkoutProvider.overrideWith((ref) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        workoutActionControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final activeSubscription = container.listen(
        activePlaybackSessionProvider,
        (_, _) {},
      );
      addTearDown(activeSubscription.close);
      events.add(null);
      await container.read(activePlaybackSessionProvider.future);
      final result = container
          .read(workoutActionControllerProvider.notifier)
          .save(workout);
      await Future<void>.delayed(Duration.zero);
      events.add(session(PlaybackStatus.playing));
      await Future<void>.delayed(Duration.zero);
      pending.complete(SaveWorkout(repo));
      expect(await result, isNull);
      expect(repo.saves, isEmpty);
    },
  );

  test('another workout remains savable during class', () async {
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [
        activePlaybackSessionProvider.overrideWith(
          (ref) => Stream.value(session(PlaybackStatus.playing)),
        ),
        saveWorkoutProvider.overrideWith((ref) async => SaveWorkout(repo)),
        fixtureWorkoutDetails,
        workoutControllerProvider.overrideWith(_Catalog.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      workoutActionControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final result = await container
        .read(workoutActionControllerProvider.notifier)
        .save(workout.copyWith(id: 'other'));
    expect(result?.id, 'other');
    expect(repo.saves.single.id, 'other');
  });
}

GoRouter _router(String path) => GoRouter(
  initialLocation: path,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          WorkoutEditGate(workoutId: state.pathParameters['id'], child: child),
      routes: [
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) => const _DraftEditor(),
          routes: [
            GoRoute(
              path: 'slides/:moduleId',
              builder: (context, state) => const _DraftEditor(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _DraftEditor extends StatelessWidget {
  const _DraftEditor();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const TextField(),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(content: Text('제목 수정 중')),
          ),
          child: const Text('제목 대화상자'),
        ),
      ],
    ),
  );
}

class _Catalog extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value([workout]);
}

class _Repository implements WorkoutRepository {
  final saves = <Workout>[];
  final deletes = <String>[];
  @override
  Future<Workout> save(Workout value) async {
    saves.add(value);
    return value;
  }

  @override
  Future<void> delete(String id) async {
    deletes.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
