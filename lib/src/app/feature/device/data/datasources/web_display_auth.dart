import 'dart:convert';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'web_display_auth.g.dart';

/// Keep the display separate from a controller's older, owner-authenticated
/// registration while retaining the same display across browser reloads.
String webDisplayDeviceId(String uid) =>
    'web-display-${sha256.convert(utf8.encode(uid)).toString().substring(0, 32)}';

/// A browser display has its own device identity. The owner's Google session
/// remains available to the controller and other tabs on the same origin.
@Riverpod(keepAlive: true)
Future<FirebaseAuth> webDisplayAuth(Ref ref, String ownerId) async {
  final primary = ref.watch(firebaseClientAuthProvider);
  final name = 'cloudboard-display-${primary.app.options.projectId}-$ownerId';
  final app =
      Firebase.apps.where((app) => app.name == name).firstOrNull ??
      await Firebase.initializeApp(name: name, options: primary.app.options);
  final auth = FirebaseAuth.instanceFor(app: app);
  // Wait for the SDK's persisted session before deciding to create an identity.
  final user = await auth.authStateChanges().first;
  if (user == null) await auth.signInAnonymously();
  if (auth.currentUser?.isAnonymous != true) {
    throw StateError('디스플레이 기기 인증을 확인하지 못했습니다.');
  }
  return auth;
}
