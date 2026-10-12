import 'package:cloud_board/firebase_options_development.dart';
import 'package:cloud_board/src/app/core/config/firebase_environment.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preview RTDB keeps the demo namespace after Firebase initialization',
    () {
      final options = DevelopmentFirebaseOptions.android.copyWith(
        projectId: 'demo-cloudboard-studio',
        databaseURL: studioPreviewRealtimeDatabaseUrl,
      );
      expect(
        realtimeDatabaseUrlForOptions(options),
        studioPreviewRealtimeDatabaseUrl,
      );
    },
  );
  test('ordinary RTDB connections follow the selected environment', () {
    expect(
      realtimeDatabaseUrlForOptions(null),
      FirebaseEnvironment.databaseUrl,
    );
    expect(
      realtimeDatabaseUrlForOptions(
        DevelopmentFirebaseOptions.android.copyWith(
          databaseURL: 'https://wrong-project.example.test',
        ),
      ),
      FirebaseEnvironment.databaseUrl,
    );
  });
  test('injected projects cannot bypass the selected environment', () {
    expect(
      () => FirebaseEnvironment.validateProject('cloud-board-stationd'),
      throwsStateError,
    );
    expect(
      () => FirebaseEnvironment.validateProject(
        'cloud-board-stationd',
        localPreview: true,
        hasEmulatorConfiguration: true,
      ),
      throwsStateError,
    );
    expect(
      () => FirebaseEnvironment.validateProject(
        'demo-cloudboard',
        localPreview: true,
      ),
      throwsStateError,
    );
    FirebaseEnvironment.validateProject(
      'demo-cloudboard',
      localPreview: true,
      hasEmulatorConfiguration: true,
    );
    FirebaseEnvironment.validateProject('cloud-board-development');
  });
  test(
    'mixed SDK endpoints or credentials fail even with the right projectId',
    () {
      const expected = DevelopmentFirebaseOptions.android;
      FirebaseEnvironment.validateOptions(expected, expected);
      for (final changed in [
        expected.copyWith(
          databaseURL: 'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app',
        ),
        expected.copyWith(apiKey: 'other-project-key'),
        expected.copyWith(appId: 'other-project-app'),
        expected.copyWith(
          storageBucket: 'cloud-board-stationd.firebasestorage.app',
        ),
      ]) {
        expect(
          () => FirebaseEnvironment.validateOptions(changed, expected),
          throwsStateError,
        );
      }
    },
  );
  test('artifact binding contains the same compile-time selector inputs', () {
    const configured = String.fromEnvironment('FIREBASE_ENV');
    expect(
      FirebaseEnvironment.compiledReleaseBinding,
      startsWith('cloudboard-release-binding:env=$configured;flavor='),
    );
    for (final environment in ['development', 'production']) {
      expect(
        FirebaseEnvironment.resolve(define: environment, flavor: environment),
        environment,
      );
    }
    expect(
      () => FirebaseEnvironment.resolve(
        define: 'development',
        flavor: 'production',
      ),
      throwsStateError,
    );
  });
  test('unqualified runs are isolated from production', () {
    expect(FirebaseEnvironment.resolve(), 'development');
    expect(FirebaseEnvironment.resolve(flavor: 'production'), 'production');
    expect(FirebaseEnvironment.resolve(define: 'development'), 'development');
  });
  test(
    'invalid or mixed native/Dart environments fail before initialization',
    () {
      expect(
        () => FirebaseEnvironment.resolve(define: 'prod'),
        throwsStateError,
      );
      expect(
        () => FirebaseEnvironment.resolve(
          define: 'production',
          flavor: 'development',
        ),
        throwsStateError,
      );
    },
  );
}
