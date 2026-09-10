import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/firebase_options.dart';
import 'package:cloud_board/src/app/app.dart';
import 'package:cloud_board/src/app/bootstrap.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      initialize: _initialize,
      builder: (isTv) => ProviderScope(
        overrides: [androidTvProvider.overrideWith((ref) async => isTv)],
        child: const XonBoardApp(),
      ),
    ),
  );
}

Future<bool> _initialize() async {
  // Neither operation depends on the other. The bootstrap has already painted.
  final results = await Future.wait<Object>([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    const DeviceFormFactorDataSource().isAndroidTv(),
  ]);
  final isTv = results[1] as bool;
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    if (isTv && FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously().timeout(
          const Duration(seconds: 15),
        );
      } catch (error, stack) {
        // Keep the login screen available if automatic TV authentication fails.
        FirebaseCrashlytics.instance.recordError(error, stack);
      }
    }
  }
  return isTv;
}
