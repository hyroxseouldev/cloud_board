import 'package:cloud_board/firebase_options_development.dart';
import 'package:cloud_board/src/app/core/config/firebase_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mixed SDK endpoints or credentials fail even with the right projectId', () {
    const expected = DevelopmentFirebaseOptions.android;
    FirebaseEnvironment.validateOptions(expected, expected);
    for (final changed in [
      expected.copyWith(databaseURL: 'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app'),
      expected.copyWith(apiKey: 'other-project-key'),
      expected.copyWith(appId: 'other-project-app'),
      expected.copyWith(storageBucket: 'cloud-board-stationd.firebasestorage.app'),
    ]) {
      expect(() => FirebaseEnvironment.validateOptions(changed, expected), throwsStateError);
    }
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
