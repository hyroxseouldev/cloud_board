import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'package:cloud_board/firebase_options.dart';
import 'package:cloud_board/firebase_options_development.dart';

/// Build identity is explicit and must agree with the native Firebase app.
/// An unqualified local/web run always uses development, never production.
abstract final class FirebaseEnvironment {
  static const _configuredEnvironment = String.fromEnvironment('FIREBASE_ENV');
  static const _configuredFlavor = appFlavor;

  /// Retained in the AOT artifact so the upload gate can inspect the exact
  /// compile-time inputs also consumed by [name], for every native ABI.
  @pragma('vm:entry-point')
  static String get compiledReleaseBinding =>
      'cloudboard-release-binding:env=$_configuredEnvironment;'
      'flavor=$_configuredFlavor;';

  static String resolve({String define = '', String? flavor}) {
    final selected = define.isNotEmpty ? define : (flavor ?? 'development');
    if (!const ['development', 'production'].contains(selected)) {
      throw StateError('Unknown Firebase environment: $selected');
    }
    if (flavor != null && flavor != selected) {
      throw StateError('Native flavor and Firebase environment disagree.');
    }
    return selected;
  }

  static String get name => resolve(
    define: _configuredEnvironment,
    flavor: kIsWeb ? null : _configuredFlavor,
  );

  static bool get isProduction => name == 'production';
  static String get projectId =>
      isProduction ? 'cloud-board-stationd' : 'cloud-board-development';
  static String get databaseUrl => isProduction
      ? 'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app'
      : 'https://cloud-board-development-default-rtdb.asia-southeast1.firebasedatabase.app';

  static FirebaseOptions get options => isProduction
      ? DefaultFirebaseOptions.currentPlatform
      : DevelopmentFirebaseOptions.currentPlatform;

  static void validateProject(
    String actualProject, {
    bool localPreview = false,
    bool hasEmulatorConfiguration = false,
  }) {
    if (localPreview) {
      if (!actualProject.startsWith('demo-') || !hasEmulatorConfiguration) {
        throw StateError(
          'Local preview requires a demo project and emulator configuration.',
        );
      }
    } else if (actualProject != projectId) {
      throw StateError(
        'Firebase project does not match the selected environment.',
      );
    }
  }

  static void validateOptions(
    FirebaseOptions actual,
    FirebaseOptions expected,
  ) {
    if (actual != expected) {
      throw StateError(
        'Firebase SDK credentials or endpoints do not match the selected environment.',
      );
    }
  }

  static void validateLaunch(FirebaseOptions effectiveOptions) {
    if (isProduction &&
        !kReleaseMode &&
        !const bool.fromEnvironment('ALLOW_PRODUCTION_DEBUG')) {
      throw StateError(
        'Production debugging requires ALLOW_PRODUCTION_DEBUG=true. '
        'Use the development flavor for normal development.',
      );
    }
    validateProject(effectiveOptions.projectId);
    validateOptions(effectiveOptions, options);
  }
}
