import 'dart:async';

import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test('first paint reads one page; repeated next requests share a fetch; full search drains pages', () async {
    final repo = _PagedRepository();
    final c = _container(repo);
    addTearDown(c.dispose);
    await c.read(workoutControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(repo.reads, 1);
    expect(c.read(workoutControllerProvider).requireValue.length, 24);
    expect(c.read(workoutCatalogStatusProvider).hasMore, isTrue);
    repo.gate = Completer<void>();
    final controller = c.read(workoutControllerProvider.notifier);
    final first = controller.loadMore();
    final second = controller.loadMore();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(repo.reads, 2);
    repo.gate!.complete();
    await first;
    expect(c.read(workoutControllerProvider).requireValue.length, 48);
    expect((await controller.loadComplete()).length, 60);
    expect(repo.reads, 3);
    expect(c.read(workoutCatalogStatusProvider).hasMore, isFalse);
  });

  test(
    'next-page failure retains rows; refresh retries only the loaded window',
    () async {
      final repo = _PagedRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(workoutControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      final controller = c.read(workoutControllerProvider.notifier);
      repo.failPage = 1;
      await expectLater(controller.loadMore(), throwsStateError);
      expect(c.read(workoutControllerProvider).requireValue.length, 24);
      expect(c.read(workoutCatalogStatusProvider).error, isA<StateError>());
      repo.failPage = null;
      await controller.refresh();
      expect(repo.reads, 3); // initial, failed next, refreshed first
      expect(c.read(workoutControllerProvider).requireValue.length, 24);
      expect(c.read(workoutCatalogStatusProvider).hasMore, isTrue);
      expect((await controller.loadComplete()).length, 60);
    },
  );

  test('a refresh reconciles deletions but preserves saves made during the request', () async {
    final repo = _PagedRepository();
    final c = _container(repo);
    addTearDown(c.dispose);
    final controller = c.read(workoutControllerProvider.notifier);
    await controller.loadComplete();
    repo.items.removeAt(0);
    repo.gate = Completer<void>();
    final refresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    controller.upsert(_workout('local'));
    controller.remove('w1');
    repo.gate!.complete();
    await refresh;
    final ids = c.read(workoutControllerProvider).requireValue.map((e) => e.id);
    expect(ids, contains('local'));
    expect(ids, isNot(contains('w0')));
    expect(ids, isNot(contains('w1')));
    expect(c.read(workoutCatalogStatusProvider).hasMore, isFalse);
  });

  test('cached rows appear before server response and an offline error keeps them usable', () async {
    final repo = _PagedRepository()
      ..cached = [_summary('cached')]
      ..failPage = 0;
    final c = _container(repo);
    addTearDown(c.dispose);
    expect(
      (await c.read(workoutControllerProvider.future)).single.id,
      'cached',
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.read(workoutControllerProvider).value?.single.id, 'cached');
  });

  test(
    'next demand waits for the initial server read behind visible cache',
    () async {
      final repo = _PagedRepository()
        ..cached = [_summary('cached')]
        ..gate = Completer<void>();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(workoutControllerProvider.future);
      final next = c.read(workoutControllerProvider.notifier).loadMore();
      await Future<void>.delayed(Duration.zero);
      expect(repo.reads, 1);
      repo.gate!.complete();
      await next;
      expect(c.read(workoutControllerProvider).requireValue.length, 48);
      expect(repo.reads, 2);
    },
  );

  test(
    'complete demand retries an initial error without cached rows',
    () async {
      final repo = _PagedRepository()..failPage = 0;
      final c = _container(repo);
      addTearDown(c.dispose);
      await expectLater(
        c.read(workoutControllerProvider.future),
        throwsStateError,
      );
      repo.failPage = null;
      final result = await c
          .read(workoutControllerProvider.notifier)
          .loadComplete();
      expect(result.length, 60);
      expect(c.read(workoutCatalogStatusProvider).hasMore, isFalse);
    },
  );

  test('an old account page and full search cannot expose or overwrite the next account', () async {
    final auth = StreamController<AuthUser?>();
    final first = _PagedRepository();
    final second = _PagedRepository()..items = [_summary('new-account')];
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        loadWorkoutsProvider.overrideWith((ref) async {
          final user = await ref.watch(authStateProvider.future);
          return LoadWorkouts(user?.id == 'u' ? first : second);
        }),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(auth.close);
    c.listen(workoutControllerProvider, (_, _) {});
    auth.add(
      const AuthUser(id: 'u', email: '', displayName: '', photoUrl: null),
    );
    await c.read(workoutControllerProvider.future);
    await Future<void>.delayed(Duration.zero);
    first.gate = Completer<void>();
    final oldSearch = c.read(workoutControllerProvider.notifier).loadComplete();
    await Future<void>.delayed(Duration.zero);
    expect(first.reads, 2);
    auth.add(
      const AuthUser(id: 'other', email: '', displayName: '', photoUrl: null),
    );
    await Future<void>.delayed(Duration.zero);
    await c.pump();
    expect(
      (await c.read(workoutControllerProvider.notifier).loadComplete())
          .single
          .id,
      'new-account',
    );
    first.gate!.complete();
    expect(await oldSearch, isEmpty);
    expect(
      c.read(workoutControllerProvider).requireValue.single.id,
      'new-account',
    );
    expect(second.reads, 1);
  });
}

ProviderContainer _container(_PagedRepository repo) {
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const AuthUser(id: 'u', email: '', displayName: '', photoUrl: null),
        ),
      ),
      loadWorkoutsProvider.overrideWith((ref) async => LoadWorkouts(repo)),
    ],
  );
  c.listen(workoutControllerProvider, (_, _) {});
  c.listen(workoutCatalogStatusProvider, (_, _) {});
  return c;
}

Workout _workout(String id) => Workout.empty(
  id,
  const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
);
WorkoutSummary _summary(String id) => summarizeWorkout(_workout(id));

class _PagedRepository implements WorkoutRepository, PagedWorkoutCatalog {
  var items = List.generate(60, (i) => _summary('w$i'));
  List<WorkoutSummary> cached = [];
  int reads = 0;
  int? failPage;
  Completer<void>? gate;
  @override
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false}) async* {
    if (cached.isNotEmpty) yield WorkoutCatalogPage(cached, cached: true);
    var offset = 0;
    while (true) {
      reads++;
      await gate?.future;
      if (offset ~/ 24 == failPage) throw StateError('offline');
      offset = (offset + 24).clamp(0, items.length);
      yield WorkoutCatalogPage(
        items.take(offset).toList(),
        complete: offset == items.length,
      );
      if (offset == items.length) return;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
