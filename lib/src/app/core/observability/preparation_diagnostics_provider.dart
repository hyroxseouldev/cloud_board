import 'dart:async';

import 'package:cloud_board/src/app/core/observability/preparation_diagnostics.dart';
import 'package:cloud_board/src/app/core/observability/preparation_probe.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preparation_diagnostics_provider.g.dart';

@Riverpod(keepAlive: true)
PreparationDiagnostics preparationDiagnostics(Ref ref) {
  // Unit/widget tests do not start platform or network listeners.
  if (Firebase.apps.isEmpty) return PreparationDiagnostics();
  final auth = ref.watch(firebaseClientAuthProvider);
  final identity = ref.watch(
    firebaseAccountUserProvider.select((v) => v.value?.uid),
  );
  final owner = ref.watch(accountOwnerIdProvider.select((v) => v.value));
  final databaseUrl = cloudBoardRealtimeDatabaseUrl;
  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: databaseUrl,
  );
  var disposed = false;
  final diagnostics = PreparationDiagnostics(
    probe:
        identity == null ||
            owner == null ||
            identity != owner ||
            auth.app.options.projectId.startsWith('demo-')
        ? null
        : (requestId) => probePreparationRequest(
            requestId: requestId,
            ownerId: owner,
            databaseUrl: databaseUrl,
            projectId: auth.app.options.projectId,
            isCurrentAccount: () =>
                !disposed && auth.currentUser?.uid == identity,
            readToken: () async => auth.currentUser?.getIdToken(),
          ),
  );
  final subscription = database
      .ref('.info/connected')
      .onValue
      .listen(
        (event) => diagnostics.connectionChanged(event.snapshot.value == true),
        onError: (Object _) => diagnostics.connectionChanged(null, error: true),
      );
  diagnostics.lifecycleChanged(
    WidgetsBinding.instance.lifecycleState?.name ?? 'unknown',
  );
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) => diagnostics.lifecycleChanged(state.name),
  );
  ref.onDispose(() {
    disposed = true;
    diagnostics.dispose();
    lifecycle.dispose();
    unawaited(subscription.cancel());
  });
  return diagnostics;
}
