import 'dart:async';

import 'package:cloud_board/src/app/feature/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cloud_board/src/app/feature/auth/data/datasources/user_profile_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restored auth is delivered without waiting for profile network writes',
    () async {
      final auth = _AuthSource();
      final profiles = _Profiles();
      final repository = FirebaseAuthRepository(auth, profiles);
      final received = <String?>[];
      final subscription = repository.authStateChanges().listen(
        (user) => received.add(user?.id),
      );
      auth.users.add(_User());
      auth.users.add(_User());
      await Future<void>.delayed(Duration.zero);
      expect(received, ['u', 'u']);
      expect(profiles.calls, 1);
      expect(profiles.pending.isCompleted, isFalse);
      profiles.pending.complete();
      await subscription.cancel();
      await auth.users.close();
    },
  );
}

class _AuthSource implements FirebaseAuthDataSource {
  final users = StreamController<User?>();
  @override
  Stream<User?> authStateChanges() => users.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements UserProfileFirestoreDataSource {
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> upsert(User user) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  String get uid => 'u';
  @override
  String? get email => 'user@example.com';
  @override
  String? get displayName => 'Coach';
  @override
  String? get photoURL => null;
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
