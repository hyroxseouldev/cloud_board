import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/firebase_options.dart';
import 'package:cloud_board/src/app/app.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    final isTv = await const DeviceFormFactorDataSource().isAndroidTv();
    if (isTv && FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (error, stack) {
        await FirebaseCrashlytics.instance.recordError(error, stack);
      }
    }
  }
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize();
    await initializeWorkoutMediaController();
  }
  runApp(const ProviderScope(child: XonBoardApp()));
}
