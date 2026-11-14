import 'dart:async';

import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_list_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthUser user(String id) =>
    AuthUser(id: id, email: '', displayName: 'Coach', photoUrl: null);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));
ProviderContainer mount({
  String owner = 'a',
  Stream<AuthUser?>? accounts,
  HomeWorkoutLayoutStore? store,
}) {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(
        (_) => accounts ?? Stream.value(user(owner)),
      ),
      if (store != null)
        homeWorkoutLayoutStoreProvider.overrideWithValue(store),
    ],
  );
  container.listen(homeWorkoutLayoutProvider, (_, _) {});
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'new account defaults grid; explicit list survives provider recreation',
    () async {
      final first = mount();
      await settle();
      expect(first.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.grid);
      expect(
        await first
            .read(homeWorkoutLayoutProvider.notifier)
            .select(HomeWorkoutLayout.list),
        isTrue,
      );
      first.dispose();
      final reopened = mount();
      await settle();
      expect(reopened.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.list);
      reopened.dispose();
    },
  );
  test('existing stored choice survives default and continuous/paged policy remains independent', () async {
    SharedPreferences.setMockInitialValues({'home.workoutLayout.v1.a': 'list'});
    final container = mount();
    addTearDown(container.dispose);
    await settle();
    expect(container.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.list);
    container
        .read(workoutListModeControllerProvider.notifier)
        .select(WorkoutListMode.paged);
    await container
        .read(homeWorkoutLayoutProvider.notifier)
        .select(HomeWorkoutLayout.grid);
    expect(
      container.read(workoutListModeControllerProvider),
      WorkoutListMode.paged,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'home.workoutLayout.v1.a',
      ),
      'grid',
    );
  });
  test('logout and account switch isolate selections, returning account restores its choice', () async {
    final accounts = StreamController<AuthUser?>();
    final container = mount(accounts: accounts.stream);
    addTearDown(container.dispose);
    addTearDown(accounts.close);
    accounts.add(user('a'));
    await settle();
    await container
        .read(homeWorkoutLayoutProvider.notifier)
        .select(HomeWorkoutLayout.list);
    accounts.add(null);
    await settle();
    expect(container.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.grid);
    accounts.add(user('b'));
    await settle();
    expect(container.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.grid);
    accounts.add(user('a'));
    await settle();
    expect(container.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.list);
  });
  test('late preference read cannot overwrite a new selection; rapid writes retain the last selection', () async {
    final store = _SlowStore();
    final container = mount(store: store);
    addTearDown(container.dispose);
    await settle();
    final controller = container.read(homeWorkoutLayoutProvider.notifier);
    final one = controller.select(HomeWorkoutLayout.list);
    final two = controller.select(HomeWorkoutLayout.grid);
    final three = controller.select(HomeWorkoutLayout.list);
    store.readGate.complete(HomeWorkoutLayout.grid);
    await Future.wait([one, two, three]);
    await settle();
    expect(container.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.list);
    expect(store.written, [
      HomeWorkoutLayout.list,
      HomeWorkoutLayout.grid,
      HomeWorkoutLayout.list,
    ]);
  });
  test('local storage failure is reported while the visit retains the requested layout', () async {
    final container = mount(store: _FailingStore());
    addTearDown(container.dispose);
    await settle();
    expect(
      await container
          .read(homeWorkoutLayoutProvider.notifier)
          .select(HomeWorkoutLayout.list),
      isFalse,
    );
    expect(container.read(homeWorkoutLayoutProvider), HomeWorkoutLayout.list);
  });
}

class _SlowStore extends HomeWorkoutLayoutStore {
  final readGate = Completer<HomeWorkoutLayout?>();
  final written = <HomeWorkoutLayout>[];
  @override
  Future<HomeWorkoutLayout?> read(String ownerId) => readGate.future;
  @override
  Future<bool> write(String ownerId, HomeWorkoutLayout layout) async {
    await settle();
    written.add(layout);
    return true;
  }
}

class _FailingStore extends HomeWorkoutLayoutStore {
  @override
  Future<HomeWorkoutLayout?> read(String ownerId) async =>
      throw StateError('unavailable');
  @override
  Future<bool> write(String ownerId, HomeWorkoutLayout layout) async => false;
}
