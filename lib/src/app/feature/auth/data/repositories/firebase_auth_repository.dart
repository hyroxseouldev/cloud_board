import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';
import '../datasources/user_profile_firestore_data_source.dart';

part 'firebase_auth_repository.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuthDataSource firebaseAuthDataSource(Ref ref) =>
    FirebaseAuthDataSource(FirebaseAuth.instance, GoogleSignIn.instance);

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => FirebaseAuthRepository(
  ref.watch(firebaseAuthDataSourceProvider),
  UserProfileFirestoreDataSource(FirebaseFirestore.instance),
);

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._dataSource, this._profileDataSource);

  final FirebaseAuthDataSource _dataSource;
  final UserProfileFirestoreDataSource _profileDataSource;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _dataSource.authStateChanges().asyncMap((user) async {
        if (user != null) await _profileDataSource.upsert(user);
        return _mapUser(user);
      });

  @override
  Future<AuthUser> signInWithGoogle() async {
    final credential = await _dataSource.signInWithGoogle();
    final user = credential.user;
    if (user == null) {
      throw StateError('로그인한 사용자 정보를 불러오지 못했습니다.');
    }
    await _profileDataSource.upsert(user);
    return _mapUser(user)!;
  }

  @override
  Future<void> signOut() => _dataSource.signOut();

  AuthUser? _mapUser(User? user) => user == null
      ? null
      : AuthUser(
          id: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '사용자',
          photoUrl: user.photoURL,
        );
}
