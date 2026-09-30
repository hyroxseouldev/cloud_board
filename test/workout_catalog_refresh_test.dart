import 'dart:async';

import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test(
    'refresh keeps old rows until complete and preserves edits made in flight',
    () async {
      final repository = _Repository([_workout('a'), _workout('b')]);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(workoutControllerProvider.notifier).loadComplete();
      final controller = container.read(workoutControllerProvider.notifier);
      controller.upsert(_workout('a', name: 'Previous local edit'));
      repository.server = [
        _workout('a', name: 'New server edit'),
        _workout('b'),
        _workout('c'),
      ];
      repository.gate = Completer<void>();
      final refresh = controller.refresh();
      final duplicate = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(repository.refreshes, 1);
      expect(
        container.read(workoutControllerProvider).requireValue.map((w) => w.id),
        ['a', 'b'],
      );
      controller.remove('b');
      controller.upsert(_workout('d', name: 'Saved during refresh'));
      repository.gate!.complete();
      await Future.wait([refresh, duplicate]);
      final result = container.read(workoutControllerProvider).requireValue;
      expect(result.map((w) => w.id).toSet(), {'a', 'c', 'd'});
      expect(result.firstWhere((w) => w.id == 'a').name, 'New server edit');
      expect(
        result.firstWhere((w) => w.id == 'd').name,
        'Saved during refresh',
      );
    },
  );

  test(
    'failed refresh keeps the last usable list and can be retried',
    () async {
      final repository = _Repository([_workout('a')]);
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(workoutControllerProvider.notifier);
      await controller.loadComplete();
      repository.fail = true;
      await expectLater(controller.refresh(), throwsStateError);
      expect(container.read(workoutControllerProvider).hasError, isFalse);
      expect(
        container.read(workoutControllerProvider).requireValue.single.id,
        'a',
      );
      repository.fail = false;
      repository.server = [_workout('b')];
      await controller.refresh();
      expect(
        container.read(workoutControllerProvider).requireValue.single.id,
        'b',
      );
      expect(repository.refreshes, 2);
    },
  );

  test(
    'an old account refresh cannot overwrite the new account catalog',
    () async {
      final auth = StreamController<AuthUser?>();
      final first = _Repository([_workout('a')]);
      final second = _Repository([_workout('z')]);
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => auth.stream),
          loadWorkoutsProvider.overrideWith((ref) async {
            final user = await ref.watch(authStateProvider.future);
            return LoadWorkouts(user?.id == 'u' ? first : second);
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      container.listen(workoutControllerProvider, (_, _) {});
      auth.add(_user('u'));
      await container.read(workoutControllerProvider.notifier).loadComplete();
      first.gate = Completer<void>();
      final pending = container
          .read(workoutControllerProvider.notifier)
          .refresh();
      await Future<void>.delayed(Duration.zero);
      auth.add(_user('other'));
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      await container.read(workoutControllerProvider.notifier).loadComplete();
      expect(
        container.read(workoutControllerProvider).requireValue.single.id,
        'z',
      );
      first.gate!.complete();
      await pending;
      expect(
        container.read(workoutControllerProvider).requireValue.single.id,
        'z',
      );
    },
  );
}

ProviderContainer _container(_Repository repository) {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_user('u'))),
      loadWorkoutsProvider.overrideWith(
        (ref) async => LoadWorkouts(repository),
      ),
    ],
  );
  container.listen(workoutControllerProvider, (_, _) {});
  return container;
}

AuthUser _user(String id) =>
    AuthUser(id: id, email: '', displayName: '', photoUrl: null);
Workout _workout(String id, {String? name}) => Workout.empty(
  id,
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
).copyWith(name: name ?? id, updatedAt: DateTime(2026, 9, 30));

class _Repository implements WorkoutRepository {
  _Repository(this.cached);
  final List<Workout> cached;
  List<Workout>? server;
  Completer<void>? gate;
  bool fail = false;
  int refreshes = 0;
  @override
  Stream<List<WorkoutSummary>> watchSummaries({
    bool requireServer = false,
  }) async* {
    if (requireServer) refreshes++;
    yield cached.map(summarizeWorkout).toList();
    if (gate != null) await gate!.future;
    if (fail) throw StateError('offline');
    yield (server ?? cached).map(summarizeWorkout).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
