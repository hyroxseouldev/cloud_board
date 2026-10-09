import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
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
  runCloudBoard();
}

/// The separate local-preview entry point configures emulators before providers
/// can read Firebase. Normal builds always use the production configuration.
void runCloudBoard({
  FirebaseOptions? firebaseOptions,
  Future<void> Function()? configureFirebase,
  bool localPreview = false,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      initialize: () =>
          _initialize(firebaseOptions, configureFirebase, localPreview),
      builder: (isTv) => ProviderScope(
        overrides: [androidTvProvider.overrideWith((ref) async => isTv)],
        child: TvPlaybackLifecycle(isTv: isTv, child: const XonBoardApp()),
      ),
    ),
  );
}

Future<bool> _initialize(
  FirebaseOptions? firebaseOptions,
  Future<void> Function()? configureFirebase,
  bool localPreview,
) async {
  // Neither operation depends on the other. The bootstrap has already painted.
  final results = await Future.wait<Object>([
    Firebase.initializeApp(
      options: firebaseOptions ?? DefaultFirebaseOptions.currentPlatform,
    ),
    const DeviceFormFactorDataSource().isAndroidTv(),
  ]);
  await configureFirebase?.call();
  final isTv = results[1] as bool;
  final reporter = await initializeDiagnostics(
    isTv: isTv,
    localOnly: localPreview,
  );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.capture(
      details.exception,
      details.stack ?? StackTrace.current,
      action: 'global.flutter',
      fatal: true,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.capture(error, stack, action: 'global.platform', fatal: true);
    return true;
  };
  if (!kIsWeb) {
    if (isTv && FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously().timeout(
          const Duration(seconds: 15),
        );
      } catch (error, stack) {
        // Keep the login screen available if automatic TV authentication fails.
        reporter.capture(error, stack, action: 'tv.authentication');
      }
    }
  }
  return isTv;
}
