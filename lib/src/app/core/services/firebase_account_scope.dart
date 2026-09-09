import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_account_scope.g.dart';

const cloudBoardRealtimeDatabaseUrl =
    'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app';

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
