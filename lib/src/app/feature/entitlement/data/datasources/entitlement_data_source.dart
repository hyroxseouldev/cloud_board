import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/models/store_entitlement_model.dart';

class EntitlementDataSource {
  Stream<bool> watchConnection() =>
      FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: cloudBoardRealtimeDatabaseUrl,
          )
          .ref('.info/connected')
          .onValue
          .map((e) => e.snapshot.value == true)
          .distinct();
  Stream<StoreEntitlement> watch(String uid) {
    late StreamController<StoreEntitlement> out;
    StreamSubscription? listener, clock;
    Timer? expiry;
    var model = const StoreEntitlementModel();
    var confirmed = false;
    var offset = 0;
    void emit() {
      if (out.isClosed) return;
      final now = DateTime.now().millisecondsSinceEpoch + offset;
      out.add(model.toEntity(uid, confirmed, now));
      expiry?.cancel();
      final remaining = model.validUntilMs - now;
      if (remaining > 0) {
        expiry = Timer(Duration(milliseconds: remaining + 1), emit);
      }
    }

    out = StreamController<StoreEntitlement>(
      onListen: () {
        out.add(StoreEntitlement(ownerId: uid));
        clock =
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: cloudBoardRealtimeDatabaseUrl,
            ).ref('.info/serverTimeOffset').onValue.listen(
              (event) {
                offset = (event.snapshot.value as num?)?.toInt() ?? 0;
                emit();
              },
              onError: (Object error, StackTrace stack) =>
                  out.addError(error, stack),
            );
        listener = FirebaseFirestore.instance
            .doc('subscriptionEntitlements/$uid')
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) {
                model = StoreEntitlementModel.fromJson(snapshot.data() ?? {});
                confirmed = !snapshot.metadata.isFromCache;
                emit();
              },
              onError: (Object error, StackTrace stack) {
                confirmed = false;
                emit();
                out.addError(error, stack);
              },
            );
      },
      onCancel: () async {
        expiry?.cancel();
        await listener?.cancel();
        await clock?.cancel();
      },
    );
    return out.stream;
  }

  Future<String> link() async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('cloudboardLinkAccount').call<Map<String, dynamic>>();
    return result.data['status'] as String? ?? 'connection_unavailable';
  }
}
