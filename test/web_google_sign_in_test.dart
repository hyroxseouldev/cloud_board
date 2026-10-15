import 'package:cloud_board/firebase_options_development.dart';
import 'package:cloud_board/src/app/feature/auth/data/datasources/web_google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _App implements FirebaseApp {
  _App(this.options);
  @override
  final FirebaseOptions options;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(FirebaseOptions options) : app = _App(options);
  @override
  final FirebaseApp app;
  final calls = <String>[];
  final credential = _Credential();
  Object? failure;

  @override
  Future<void> signInWithRedirect(AuthProvider provider) async {
    expect(provider.providerId, 'google.com');
    calls.add('redirect');
    if (failure != null) throw failure!;
  }

  @override
  Future<UserCredential> getRedirectResult() async {
    calls.add('redirect-result');
    return credential;
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    expect(provider.providerId, 'google.com');
    calls.add('popup');
    return credential;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const development = DevelopmentFirebaseOptions.web;
  test('hosted development uses Google redirect on its auth origin', () async {
    final auth = _Auth(development);
    final result = await signInWithGoogleOnWeb(
      auth,
      pageUri: Uri.parse('https://${development.authDomain}/#/login'),
    );
    expect(result, same(auth.credential));
    expect(auth.calls, ['redirect', 'redirect-result']);
  });

  test('redirect errors reach the existing login error handler', () async {
    final auth = _Auth(development);
    final error = FirebaseAuthException(code: 'network-request-failed');
    auth.failure = error;
    await expectLater(
      signInWithGoogleOnWeb(
        auth,
        pageUri: Uri.parse('https://${development.authDomain}/'),
      ),
      throwsA(same(error)),
    );
    expect(auth.calls, ['redirect']);
  });

  test('local previews and production preserve popup authentication', () async {
    for (final scenario in [
      (development, 'http://localhost:8767/'),
      (
        development.copyWith(
          projectId: 'cloud-board-stationd',
          authDomain: 'cloud-board-stationd.firebaseapp.com',
        ),
        'https://cloud-board-stationd.firebaseapp.com/',
      ),
    ]) {
      final auth = _Auth(scenario.$1);
      await signInWithGoogleOnWeb(auth, pageUri: Uri.parse(scenario.$2));
      expect(auth.calls, ['popup']);
    }
  });
}
