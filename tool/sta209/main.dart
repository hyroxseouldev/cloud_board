// Local-only STA-209 application harness. No business providers are replaced.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/main.dart' as app;
import 'package:cloud_board/src/app/core/config/firebase_environment.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

SemanticsHandle? _semantics;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode ||
      FirebaseEnvironment.isProduction ||
      !kIsWeb ||
      Uri.base.host != 'localhost') {
    throw StateError('Local development web harness only');
  }
  _semantics ??= SemanticsBinding.instance.ensureSemantics();
  final harnessPrefs = await SharedPreferences.getInstance();
  final role =
      Uri.base.queryParameters['role'] ??
      harnessPrefs.getString('sta209_role') ??
      'controller';
  await harnessPrefs.setString('sta209_role', role);
  final prepare = Uri.base.queryParameters['prepare'] == 'true';
  final options = FirebaseEnvironment.options.copyWith(
    apiKey: 'fake-sta209-emulator-key',
    projectId: 'demo-cloudboard-studio',
    storageBucket: 'demo-cloudboard-studio.appspot.com',
    databaseURL: studioPreviewRealtimeDatabaseUrl,
  );
  Future<void> configure() async {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: studioPreviewRealtimeDatabaseUrl,
    ).useDatabaseEmulator('127.0.0.1', 9000);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
    for (final region in [
      'asia-northeast3',
      'asia-southeast1',
      'us-central1',
    ]) {
      // Port 5001 deliberately has a fault responder, never real Functions.
      FirebaseFunctions.instanceFor(region: region)
          .useFunctionsEmulator('127.0.0.1', 5001);
    }
    final auth = FirebaseAuth.instance;
    await auth.authStateChanges().first;
    if (role == 'controller') {
      await auth.signInWithEmailAndPassword(
        email: 'sta209@example.test',
        password: 'local-sta209-only',
      );
    } else if (auth.currentUser == null) {
      if (!prepare) {
        throw StateError(
          'Prepare the persisted anonymous test identity first.',
        );
      }
      await auth.signInAnonymously();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'device_mode',
      role == 'controller' ? 'controller' : 'display',
    );
    if (role != 'controller') await prefs.setString('device_id', role);
  }

  if (prepare) {
    await Firebase.initializeApp(options: options);
    await configure();
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SelectableText(
            'STA209 $role UID=${FirebaseAuth.instance.currentUser!.uid}',
          ),
        ),
      ),
    );
  } else {
    app.runCloudBoard(
      firebaseOptions: options,
      localPreview: true,
      configureFirebase: configure,
    );
  }
}
