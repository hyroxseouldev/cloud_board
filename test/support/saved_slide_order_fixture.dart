import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/saved_slide_order_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/saved_slide_order_repository.dart';

/// In-memory transaction double, not Firebase or E2E evidence.
class OrderFirestore extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{};
  final events = StreamController<void>.broadcast();
  final writes = <(String, Map<String, dynamic>)>[];
  int revision = 0;
  int transactions = 0;
  bool fail = false;
  void Function()? beforeCommit;
  void put(String path, Map<String, dynamic> value) {
    docs[path] = value;
    revision++;
    events.add(null);
  }

  void seed(String uid, List<String> ids, {List<String>? order}) {
    put('users/$uid', {
      'uid': uid,
      'displayName': 'Unchanged',
      if (order != null) 'savedSlideOrder': order,
    });
    for (final id in ids) {
      put('users/$uid/slideTemplates/$id', {
        'deleted': false,
        'value': {
          'id': id,
          'name': 'Same name',
          'imageUrl': 'https://image/$id',
        },
      });
    }
  }

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    transactions++;
    for (var i = 0; i < maxAttempts; i++) {
      final before = revision;
      final tx = _Transaction(this);
      final result = await transactionHandler(tx);
      final hook = beforeCommit;
      beforeCommit = null;
      hook?.call();
      if (fail) throw StateError('offline');
      if (before != revision) continue;
      for (final (path, patch) in tx.writes) {
        writes.add((path, patch));
        put(path, {...docs[path]!, ...patch});
      }
      return result;
    }
    throw StateError('transaction contention');
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final OrderFirestore db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(db.docs[path]);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield _Snapshot(db.docs[path]);
    yield* db.events.stream.map((_) => _Snapshot(db.docs[path]));
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.db);
  final OrderFirestore db;
  final writes = <(String, Map<String, dynamic>)>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async => _Snapshot(db.docs[ref.path]) as DocumentSnapshot<T>;
  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    writes.add((ref.path, Map<String, dynamic>.from(data)));
    return this;
  }
}

class OrderAuth extends Fake implements FirebaseAuth {
  String? uid = 'owner';
  @override
  User? get currentUser => uid == null ? null : _User(uid!);
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

SavedSlideOrderRepository orderRepository(OrderFirestore db, OrderAuth auth) =>
    SavedSlideOrderRepository(SavedSlideOrderDataSource(db), auth);
