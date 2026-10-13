import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_usage.dart';

class FirebasePlanUsageRepository implements PlanUsageRepository {
  FirebasePlanUsageRepository(this.firestore, this.bootstrap);
  final FirebaseFirestore firestore;
  final Future<void> Function() bootstrap;

  @override
  Stream<PlanUsage?> watch(String ownerId) {
    var requested = false;
    late StreamController<PlanUsage?> out;
    StreamSubscription? subscription;
    out = StreamController<PlanUsage?>(
      onListen: () {
        subscription = firestore
            .doc('users/$ownerId/planUsage/current')
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
              final data = snapshot.data();
              final workouts = data?['workoutCount'],
                  slides = data?['savedSlideCount'];
              if (workouts is int &&
                  workouts >= 0 &&
                  slides is int &&
                  slides >= 0) {
                out.add(
                  PlanUsage(
                    workoutCount: workouts,
                    savedSlideCount: slides,
                    serverConfirmed: !snapshot.metadata.isFromCache,
                  ),
                );
              } else {
                out.add(null);
                if (!snapshot.metadata.isFromCache && !requested) {
                  requested = true;
                  unawaited(
                    bootstrap().catchError((Object error, StackTrace stack) {
                      if (!out.isClosed) out.addError(error, stack);
                    }),
                  );
                }
              }
            }, onError: (Object e, StackTrace s) => out.addError(e, s));
      },
      onCancel: () async => subscription?.cancel(),
    );
    return out.stream;
  }

  static FirebasePlanUsageRepository create() =>
      FirebasePlanUsageRepository(FirebaseFirestore.instance, () async {
        await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
            .httpsCallable('getPlanUsage')
            .call();
      });
}
