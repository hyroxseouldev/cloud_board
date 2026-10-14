import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/config/firebase_environment.dart';
import 'package:cloud_board/src/app/app.dart';
import 'package:cloud_board/src/app/bootstrap.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';

void main() {
  runCloudBoard();
}

/// Local previews inject emulator options; all other builds validate their
/// explicit environment before any Firebase SDK can connect.
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
        overrides: [
          androidTvProvider.overrideWith((ref) async => isTv),
          // The first TV frame must never expose a cached class before its
          // foreground server handshake. Browser/controller audio is unchanged.
          tvPlaybackVisibleProvider.overrideWith(
            () => TvPlaybackVisible(initiallyVisible: !isTv),
          ),
        ],
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
  final options = firebaseOptions ?? FirebaseEnvironment.options;
  if (localPreview) {
    FirebaseEnvironment.validateProject(
      options.projectId,
      localPreview: true,
      hasEmulatorConfiguration: configureFirebase != null,
    );
  } else {
    FirebaseEnvironment.validateLaunch(options);
  }
  // Neither operation depends on the other. The bootstrap has already painted.
  final results = await Future.wait<Object>([
    Firebase.initializeApp(options: options),
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
