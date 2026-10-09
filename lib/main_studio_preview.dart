import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_board/firebase_options.dart';
import 'package:cloud_board/main.dart' as app;
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

/// Debug-only, isolated simulator preview. Start and seed the emulators using
/// tool/studio-preview before launching; no production Firebase writes occur.
void main() {
  if (!kDebugMode) {
    throw StateError('Studio preview is only available in debug builds.');
  }
  app.runCloudBoard(
    firebaseOptions: DefaultFirebaseOptions.currentPlatform.copyWith(
      projectId: 'demo-cloudboard-studio',
      storageBucket: 'demo-cloudboard-studio.appspot.com',
      databaseURL: cloudBoardRealtimeDatabaseUrl,
    ),
    localPreview: true,
    configureFirebase: () async {
      const host = '127.0.0.1';
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      for (final region in [
        'asia-northeast3',
        'asia-southeast1',
        'us-central1',
      ]) {
        FirebaseFunctions.instanceFor(region: region)
            .useFunctionsEmulator(host, 5001);
      }
      for (final database in [
        FirebaseDatabase.instance,
        FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: cloudBoardRealtimeDatabaseUrl,
        ),
      ]) {
        database.useDatabaseEmulator(host, 9000);
      }
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      // This public fixture exists only in the Auth emulator; it is not a key.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'studio-preview@example.test',
        password: 'local-preview-only',
      );
    },
  );
}
