import 'package:cloud_board/src/app/core/config/firebase_environment.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_account_scope.g.dart';

const studioPreviewRealtimeDatabaseUrl =
    'https://demo-cloudboard-studio-default-rtdb.asia-southeast1.firebasedatabase.app';

String get cloudBoardRealtimeDatabaseUrl => realtimeDatabaseUrlForOptions(
  Firebase.apps.where((app) => app.name == '[DEFAULT]').firstOrNull?.options,
);

/// Ordinary builds always use their selected environment. The debug-only
/// preview initializes a demo app and connects its database to localhost before
/// providers mount; preserve that demo namespace instead of the dev namespace.
@visibleForTesting
String realtimeDatabaseUrlForOptions(FirebaseOptions? initializedOptions) =>
    kDebugMode && initializedOptions?.projectId == 'demo-cloudboard-studio'
    ? studioPreviewRealtimeDatabaseUrl
    : FirebaseEnvironment.databaseUrl;

@Riverpod(keepAlive: true)
Stream<User?> firebaseAccountUser(Ref ref) =>
    FirebaseAuth.instance.userChanges();

@Riverpod(keepAlive: true)
Stream<String?> accountOwnerId(Ref ref) {
  final auth = FirebaseAuth.instance;
  final user = ref.watch(firebaseAccountUserProvider).value;
  if (user == null) return Stream.value(null);
  final directOwnerId = accountOwnerIdForUser(
    uid: user.uid,
    isAnonymous: user.isAnonymous,
  );
  if (directOwnerId != null) return Stream.value(directOwnerId);

  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: cloudBoardRealtimeDatabaseUrl,
  );
  return database
      .ref('displayAccess/${user.uid}/ownerId')
      .onValue
      .map((event) => event.snapshot.value as String?);
}

String? accountOwnerIdForUser({
  required String uid,
  required bool isAnonymous,
}) => isAnonymous ? null : uid;
