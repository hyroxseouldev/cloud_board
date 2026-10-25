import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_board/src/app/core/services/realtime_server_reader.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/existing_member_access.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/models/store_entitlement_model.dart';

class ExistingMemberAccessDataSource {
  ExistingMemberAccessDataSource(
    this.firestore,
    this.database,
    this.auth,
    this.server,
  );
  final FirebaseFirestore firestore;
  final FirebaseDatabase database;
  final FirebaseAuth auth;
  final RealtimeServerReader server;

  Stream<bool> watch(String uid) {
    late StreamController<bool> out;
    final subscriptions = <StreamSubscription<dynamic>>[];
    Map<String, dynamic>? grant;
    var connected = false, received = false, generation = 0, offset = 0;
    Timer? expiry, initialTimeout;
    Future<String?>? authenticated;
    var hasAdmission = false;
    Future<void> check() async {
      final epoch = ++generation;
      if (!connected || !received || out.isClosed) return;
      try {
        if (await authenticated == null) throw StateError('로그인 상태를 확인해 주세요.');
        final wire = await server.read('subscriptionAccess/$uid');
        if (out.isClosed ||
            epoch != generation ||
            auth.currentUser?.uid != uid) {
          return;
        }
        final now = DateTime.now().millisecondsSinceEpoch + offset;
        initialTimeout?.cancel();
        final admitted = existingMemberMayEnter(
          uid: uid,
          grant: StoreEntitlementModel.fromJson(grant ?? {})
              .toEntity(uid, true, now),
          source: grant?['source'] as String? ?? '',
          realtimeAccess: wire,
          serverNowMs: now,
        );
        hasAdmission = admitted;
        out.add(admitted);
        expiry?.cancel();
        final end = grant?['validUntilMs'];
        if (end is num && end > now) {
          expiry = Timer(Duration(milliseconds: (end - now).ceil() + 1), () {
            hasAdmission = false;
            if (!out.isClosed) out.add(false);
          });
        }
      } catch (error, stack) {
        if (!out.isClosed && epoch == generation) out.addError(error, stack);
      }
    }

    void failed(Object error, StackTrace stack) {
      ++generation;
      expiry?.cancel();
      initialTimeout?.cancel();
      hasAdmission = false;
      if (!out.isClosed) out.addError(error, stack);
    }

    out = StreamController<bool>(
      onListen: () {
        authenticated = auth.currentUser
            ?.getIdToken(true)
            .timeout(const Duration(seconds: 6));
        authenticated?.catchError((Object error, StackTrace stack) {
          failed(error, stack);
          return null;
        });
        initialTimeout = Timer(const Duration(seconds: 10), () {
          if (!hasAdmission && (!connected || !received)) {
            failed(
              StateError('서버의 이용 권한을 확인하지 못했습니다. 다시 시도해 주세요.'),
              StackTrace.current,
            );
          }
        });
        subscriptions.add(
          database.ref('.info/connected').onValue.listen((event) {
            connected = event.snapshot.value == true;
            if (!connected) {
              ++generation;
              if (received && !hasAdmission) {
                failed(StateError('네트워크 연결을 확인해 주세요.'), StackTrace.current);
              }
            } else {
              unawaited(check());
            }
          }, onError: failed),
        );
        subscriptions.add(
          database.ref('.info/serverTimeOffset').onValue.listen((event) {
            offset = (event.snapshot.value as num?)?.toInt() ?? 0;
            unawaited(check());
          }, onError: failed),
        );
        subscriptions.add(
          firestore
              .doc('subscriptionEntitlements/$uid')
              .snapshots(includeMetadataChanges: true)
              .listen((snapshot) {
                if (snapshot.metadata.isFromCache ||
                    snapshot.metadata.hasPendingWrites) {
                  return;
                }
                received = true;
                grant = snapshot.data();
                unawaited(check());
              }, onError: failed),
        );
        // A changed RTDB projection must also invalidate an earlier success. Its
        // SDK event is only a notification; check() always reads from the server.
        subscriptions.add(
          database
              .ref('subscriptionAccess/$uid')
              .onValue
              .listen((_) => unawaited(check()), onError: failed),
        );
      },
      onCancel: () async {
        ++generation;
        expiry?.cancel();
        initialTimeout?.cancel();
        await Future.wait(subscriptions.map((s) => s.cancel()));
      },
    );
    return out.stream;
  }
}
