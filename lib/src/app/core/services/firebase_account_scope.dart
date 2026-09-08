import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_account_scope.g.dart';

const cloudBoardRealtimeDatabaseUrl =
    'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app';

@Riverpod(keepAlive: true)
Stream<String?> accountOwnerId(Ref ref) async* {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    yield null;
    return;
  }
  if (!user.isAnonymous) {
    yield user.uid;
    return;
  }

  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: cloudBoardRealtimeDatabaseUrl,
  );
  yield* database
      .ref('displayAccess/${user.uid}/ownerId')
      .onValue
      .map((event) => event.snapshot.value as String?);
}
