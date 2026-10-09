import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/repositories/first_class_repository.dart';

part 'first_class_repository_impl.g.dart';

String firstClassScopeKey(String userId, String centerId) =>
    sha256.convert(utf8.encode(jsonEncode([userId, centerId]))).toString();

class FirstClassRepositoryImpl implements FirstClassRepository {
  FirstClassRepositoryImpl(this.preferences, {required this.sendEvent});
  final SharedPreferencesAsync preferences;
  final Future<void> Function(
    String userId,
    String id,
    Map<String, Object?> event,
  )
  sendEvent;

  String _key(String user, String center) =>
      'cloudboard.first-class.v1.${firstClassScopeKey(user, center)}';

  @override
  Future<FirstClassProgress> load(String userId, String centerId) async {
    final raw = await preferences.getString(_key(userId, centerId));
    if (raw != null) {
      return FirstClassProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    return FirstClassProgress(
      sessionId:
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
    );
  }

  @override
  Future<void> save(
    String userId,
    String centerId,
    FirstClassProgress progress,
  ) => preferences.setString(
    _key(userId, centerId),
    jsonEncode(progress.toJson()),
  );

  @override
  Future<void> record(
    String userId,
    String centerId,
    String sessionId,
    String event,
  ) {
    // Stable keys make retries idempotent; never include workout text/name or codes.
    final id =
        'first-class-${firstClassScopeKey(userId, centerId)}-$sessionId-$event';
    return sendEvent(userId, id, {
      'id': id,
      'type': 'onboarding_$event',
      'centerId': centerId,
      'sessionId': sessionId,
      'occurredAtMs': ServerValue.timestamp,
      'scheduled': false,
    });
  }
}

@Riverpod(keepAlive: true)
FirstClassRepository firstClassRepository(Ref ref) => FirstClassRepositoryImpl(
  SharedPreferencesAsync(),
  sendEvent: (userId, id, event) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser?.uid != userId ||
        auth.currentUser?.isAnonymous != false) {
      return;
    }
    await FirebaseDatabase.instanceFor(
          app: auth.app,
          databaseURL: cloudBoardRealtimeDatabaseUrl,
        )
        .ref('users/$userId/operations/events/$id')
        .runTransaction(
          (current) => current == null
              ? Transaction.success(event)
              : Transaction.abort(),
          applyLocally: false,
        );
  },
);
