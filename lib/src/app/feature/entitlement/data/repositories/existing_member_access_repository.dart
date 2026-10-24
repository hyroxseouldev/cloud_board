import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/services/realtime_server_reader.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/datasources/existing_member_access_data_source.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/repositories/existing_member_access_repository.dart';
part 'existing_member_access_repository.g.dart';

class ExistingMemberAccessRepositoryImpl
    implements ExistingMemberAccessRepository {
  ExistingMemberAccessRepositoryImpl(this.source);
  final ExistingMemberAccessDataSource source;
  @override
  Stream<bool> watch(String uid) => source.watch(uid);
}

@riverpod
ExistingMemberAccessRepository existingMemberAccessRepository(Ref ref) {
  final auth = ref.watch(firebaseClientAuthProvider);
  return ExistingMemberAccessRepositoryImpl(
    ExistingMemberAccessDataSource(
      FirebaseFirestore.instanceFor(app: auth.app),
      FirebaseDatabase.instanceFor(
        app: auth.app,
        databaseURL: cloudBoardRealtimeDatabaseUrl,
      ),
      auth,
      RealtimeServerReader(auth, cloudBoardRealtimeDatabaseUrl),
    ),
  );
}
