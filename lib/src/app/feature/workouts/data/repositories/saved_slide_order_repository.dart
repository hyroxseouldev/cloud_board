import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/saved_slide_order_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/saved_slide_order.dart';

part 'saved_slide_order_repository.g.dart';

class SavedSlideOrderRepository {
  SavedSlideOrderRepository(this.source, this.auth);
  final SavedSlideOrderDataSource source;
  final FirebaseAuth auth;

  void _check(String scope) {
    if (scope.isEmpty || auth.currentUser?.uid != scope) {
      throw const LibraryFailure('로그인 계정을 확인해 주세요.');
    }
  }

  Stream<List<String>> watch(String scope) async* {
    _check(scope);
    yield* source.watch(scope).map((order) {
      _check(scope);
      return order;
    });
  }

  Future<List<String>> load(String scope) async {
    _check(scope);
    final result = await source.load(scope);
    _check(scope);
    return result;
  }

  Future<List<String>> reconcile(
    String scope,
    List<String> ids, {
    SavedSlideMove? move,
  }) async {
    _check(scope);
    final result = await source.reconcile(
      scope,
      ids,
      move: move,
      checkAccount: () => _check(scope),
    );
    _check(scope);
    return result;
  }
}

@riverpod
SavedSlideOrderRepository savedSlideOrderRepository(Ref ref) =>
    SavedSlideOrderRepository(
      SavedSlideOrderDataSource(FirebaseFirestore.instance),
      FirebaseAuth.instance,
    );
