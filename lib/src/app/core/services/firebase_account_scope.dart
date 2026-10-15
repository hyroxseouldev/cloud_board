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
FirebaseAuth firebaseClientAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
Stream<User?> firebaseAccountUser(Ref ref) =>
    ref.watch(firebaseClientAuthProvider).userChanges();

@Riverpod(keepAlive: true)
Stream<String?> accountOwnerId(Ref ref) {
  final auth = ref.watch(firebaseClientAuthProvider);
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

/// Retains the identity of one asynchronous operation. Any unresolved or changed
/// owner/auth state cancels it permanently, including an A→B→A transition.
class AccountOperationScope {
  AccountOperationScope._(
    this._ref,
    this.ownerId,
    this.uid,
    this._onInvalidated,
  );

  final Ref _ref;
  final String ownerId, uid;
  final void Function()? _onInvalidated;
  void Function()? _closeOwner, _closeUser;
  bool _closed = false;

  static AccountOperationScope? capture(
    Ref ref, {
    void Function()? onInvalidated,
  }) {
    final owner = ref.read(accountOwnerIdProvider);
    final user = ref.read(firebaseAccountUserProvider);
    if (owner.isLoading ||
        owner.hasError ||
        owner.value == null ||
        user.isLoading ||
        user.hasError ||
        user.value == null) {
      return null;
    }
    final scope = AccountOperationScope._(
      ref,
      owner.value!,
      user.value!.uid,
      onInvalidated,
    );
    scope._closeOwner = ref.listen(accountOwnerIdProvider, (_, next) {
      if (next.isLoading || next.hasError || next.value != scope.ownerId) {
        scope._invalidate();
      }
    }).close;
    scope._closeUser = ref.listen(firebaseAccountUserProvider, (_, next) {
      if (next.isLoading || next.hasError || next.value?.uid != scope.uid) {
        scope._invalidate();
      }
    }).close;
    return scope;
  }

  bool get isCurrent {
    if (_closed || !_ref.mounted) return false;
    final owner = _ref.read(accountOwnerIdProvider);
    final user = _ref.read(firebaseAccountUserProvider);
    if (owner.isLoading ||
        owner.hasError ||
        owner.value != ownerId ||
        user.isLoading ||
        user.hasError ||
        user.value?.uid != uid) {
      _invalidate();
      return false;
    }
    return true;
  }

  void _invalidate() {
    if (_closed) return;
    close();
    _onInvalidated?.call();
  }

  void close() {
    _closed = true;
    _closeOwner?.call();
    _closeUser?.call();
    _closeOwner = null;
    _closeUser = null;
  }
}
