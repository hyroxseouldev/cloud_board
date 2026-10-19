import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database_platform_interface/firebase_database_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

void main() {
  for (final anonymous in [false, true]) {
    testWidgets(
      'same UID refresh preserves owner and downstream subscriptions (anonymous: $anonymous)',
      (tester) async {
        final users = StreamController<User?>.broadcast();
        final mapping = _MappingDatabase();
        final previousDatabase = DatabasePlatform.instance;
        DatabasePlatform.instance = mapping;
        final auth = _Auth(users.stream, _App('scope-$anonymous'));
        final container = ProviderContainer(
          overrides: [firebaseClientAuthProvider.overrideWithValue(auth)],
        );
        addTearDown(() async {
          container.dispose();
          DatabasePlatform.instance = previousDatabase;
          await users.close();
          await mapping.owners.close();
        });
        final observed = <AsyncValue<String?>>[];
        var dependencyBuilds = 0;
        final dependency = Provider((ref) {
          ref.watch(accountOwnerIdProvider);
          dependencyBuilds++;
          return Object();
        });
        container.listen(
          accountOwnerIdProvider,
          (_, next) => observed.add(next),
        );
        container.listen(dependency, (_, _) {});
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        users.add(_User('display', anonymous: anonymous));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        final scope = container.read(accountOwnerIdProvider);
        expect(
          scope.hasError,
          isFalse,
          reason: '${scope.error}\n${scope.stackTrace}',
        );
        expect(scope.value, anonymous ? 'center' : 'display');
        final before = container.read(dependency);
        final builds = dependencyBuilds;
        observed.clear();
        users.add(_User('display', anonymous: anonymous));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          observed,
          isEmpty,
          reason: 'A token/profile event must not emit owner loading/null',
        );
        expect(container.read(dependency), same(before));
        expect(dependencyBuilds, builds);
        expect(mapping.subscriptions, anonymous ? 1 : 0);

        if (anonymous) {
          mapping.owners.add('other-center');
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 1));
          expect(container.read(accountOwnerIdProvider).value, 'other-center');
          // Linking the same UID to an account is a real authorization change.
          users.add(_User('display', anonymous: false));
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 1));
          expect(container.read(accountOwnerIdProvider).value, 'display');
          expect(mapping.cancellations, 1);
        }
        users.add(_User('other-account'));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        expect(container.read(accountOwnerIdProvider).value, 'other-account');
        users.add(null);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        expect(container.read(accountOwnerIdProvider).value, isNull);
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
  test('signed-in account switches its database owner scope immediately', () {
    expect(
      accountOwnerIdForUser(uid: 'first-account', isAnonymous: false),
      'first-account',
    );
    expect(
      accountOwnerIdForUser(uid: 'second-account', isAnonymous: false),
      'second-account',
    );
  });

  test('anonymous display waits for its paired owner mapping', () {
    expect(
      accountOwnerIdForUser(uid: 'display-account', isAnonymous: true),
      isNull,
    );
  });
}

class _User extends Fake implements User {
  _User(this.uid, {bool anonymous = false}) : isAnonymous = anonymous;
  @override
  final String uid;
  @override
  final bool isAnonymous;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.users, this.app);
  final Stream<User?> users;
  @override
  final FirebaseApp app;
  @override
  Stream<User?> userChanges() => users;
}

class _App extends Fake implements FirebaseApp {
  _App(this.name);
  @override
  final String name;
}

class _MappingDatabase extends DatabasePlatform {
  final owners = StreamController<String?>.broadcast();
  int subscriptions = 0, cancellations = 0;
  @override
  DatabasePlatform delegateFor({
    required FirebaseApp app,
    String? databaseURL,
  }) => this;
  @override
  DatabaseReferencePlatform ref([String? path]) {
    expectSync(path, 'displayAccess/display/ownerId');
    return _MappingReference(this);
  }
}

class _MappingReference extends Fake
    with MockPlatformInterfaceMixin
    implements DatabaseReferencePlatform {
  _MappingReference(this.database);
  @override
  final _MappingDatabase database;
  @override
  Stream<DatabaseEventPlatform> onValue(QueryModifiers modifiers) =>
      Stream.multi((sink) {
        database.subscriptions++;
        sink.add(_MappingEvent(this, 'center'));
        final sub = database.owners.stream.listen(
          (owner) => sink.add(_MappingEvent(this, owner)),
        );
        sink.onCancel = () async {
          database.cancellations++;
          await sub.cancel();
        };
      });
}

class _MappingEvent extends DatabaseEventPlatform {
  _MappingEvent(DatabaseReferencePlatform ref, String? owner)
    : snapshot = _MappingSnapshot(ref, owner),
      super({'eventType': 'value'});
  @override
  final DataSnapshotPlatform snapshot;
}

class _MappingSnapshot extends DataSnapshotPlatform {
  _MappingSnapshot(DatabaseReferencePlatform ref, String? owner)
    : super(ref, {'value': owner});
}
