import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/saved_slide_order_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/saved_slide_order.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/saved_slide_order_controller.dart';

import 'support/saved_slide_order_fixture.dart';

void main() {
  test('optional legacy order, malformed values, duplicates and stale IDs', () {
    expect(readSavedSlideOrder(null), isEmpty);
    expect(readSavedSlideOrder(['a', 'a', null, 2, '../b']), ['a']);
    expect(reconcileSavedSlideOrder([], ['c', 'a', 'b']), ['a', 'b', 'c']);
    expect(
      reconcileSavedSlideOrder(['b', 'gone', 'b', 'a'], ['a', 'b', 'new']),
      ['b', 'a', 'new'],
    );
  });

  test('new repository/device reload sees order-only commit; new IDs append and deleted IDs prune', () async {
    final db = OrderFirestore()..seed('owner', ['a', 'b', 'c']);
    addTearDown(db.events.close);
    final auth = OrderAuth();
    final repo = orderRepository(db, auth);
    final contents = Map.of(db.docs);
    await repo.reconcile(
      'owner',
      ['a', 'b', 'c'],
      move: (id: 'c', beforeId: 'a', afterId: null),
    );
    expect(await orderRepository(db, auth).load('owner'), ['c', 'a', 'b']);
    for (final (path, patch) in db.writes) {
      expect(path, 'users/owner');
      expect(patch.keys, ['savedSlideOrder']);
    }
    for (final entry in contents.entries.where(
      (e) => e.key.contains('/slideTemplates/'),
    )) {
      expect(db.docs[entry.key], entry.value);
    }
    expect(db.docs['users/owner']!['displayName'], 'Unchanged');
    db.put('users/owner/slideTemplates/0-new', {'deleted': false});
    db.put('users/owner/slideTemplates/a', {'deleted': true});
    expect(await repo.reconcile('owner', ['a', 'b', 'c', '0-new']), [
      'c',
      'b',
      '0-new',
    ]);
  });

  test('concurrent add/delete/reorder rebases move against latest transaction; no lost or duplicate chips', () async {
    final db = OrderFirestore()
      ..seed('owner', ['a', 'b', 'c'], order: ['a', 'b', 'c']);
    addTearDown(db.events.close);
    final repo = orderRepository(db, OrderAuth());
    db.beforeCommit = () {
      db.put('users/owner/slideTemplates/d', {'deleted': false});
      db.put('users/owner/slideTemplates/b', {'deleted': true});
      db.put('users/owner', {
        'uid': 'owner',
        'savedSlideOrder': ['c', 'a', 'd'],
      });
    };
    final result = await repo.reconcile(
      'owner',
      ['a', 'b', 'c'],
      move: (id: 'a', beforeId: null, afterId: 'c'),
    );
    expect(result, ['c', 'a', 'd']);
    expect(result.toSet().length, result.length);
    expect(db.docs['users/owner/slideTemplates/b']!['deleted'], true);
  });

  test(
    'deleted moved item and deleted anchors cannot resurrect content',
    () async {
      final db = OrderFirestore()..seed('owner', ['a'], order: ['a', 'b']);
      addTearDown(db.events.close);
      final repo = orderRepository(db, OrderAuth());
      expect(
        await repo.reconcile(
          'owner',
          ['a', 'b'],
          move: (id: 'b', beforeId: 'a', afterId: null),
        ),
        ['a'],
      );
      expect(
        reconcileSavedSlideOrder(
          ['a', 'c'],
          ['a', 'c'],
          move: (id: 'a', beforeId: 'gone', afterId: 'c'),
        ),
        ['c', 'a'],
      );
    },
  );

  test('account separation and sign-out during a transaction prevent old account writes', () async {
    final db = OrderFirestore()
      ..seed('owner', ['a', 'b'], order: ['b', 'a'])
      ..seed('other', ['x', 'y'], order: ['x', 'y']);
    addTearDown(db.events.close);
    final auth = OrderAuth();
    final repo = orderRepository(db, auth);
    await expectLater(repo.load('other'), throwsA(isA<LibraryFailure>()));
    auth.uid = 'other';
    expect(await repo.load('other'), ['x', 'y']);
    await expectLater(
      repo.reconcile('owner', ['a']),
      throwsA(isA<LibraryFailure>()),
    );
    db.beforeCommit = () {
      auth.uid = null;
      db.revision++; // Retry checks account before reading/writing again.
    };
    await expectLater(
      repo.reconcile(
        'other',
        ['x', 'y'],
        move: (id: 'y', beforeId: 'x', afterId: null),
      ),
      throwsA(isA<LibraryFailure>()),
    );
    expect(db.writes, isEmpty);
  });

  test('controller rollback, explicit retry and remote updates retain account order', () async {
    final db = OrderFirestore()..seed('owner', ['a', 'b'], order: ['a', 'b']);
    addTearDown(db.events.close);
    final container = ProviderContainer(
      overrides: [
        savedSlideOrderRepositoryProvider.overrideWith(
          (ref) => orderRepository(db, OrderAuth()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = savedSlideOrderControllerProvider('owner');
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final controller = container.read(provider.notifier);
    db.fail = true;
    await controller.move(['a', 'b'], 0, 1);
    expect(container.read(provider).ids, ['a', 'b']);
    expect(container.read(provider).error, isNotNull);
    expect(container.read(provider).saving, false);
    db.fail = false;
    await controller.retry();
    expect(container.read(provider).ids, ['b', 'a']);
    expect(container.read(provider).error, isNull);
    db.put('users/owner', {
      'uid': 'owner',
      'savedSlideOrder': ['a', 'b'],
    });
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).ids, ['a', 'b']);
  });
}
