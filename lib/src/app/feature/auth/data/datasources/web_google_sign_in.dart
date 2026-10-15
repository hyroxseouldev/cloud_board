import 'package:firebase_auth/firebase_auth.dart';

/// Keep the development OAuth result on the same origin as its auth helper.
/// Production and local previews retain their existing popup flow.
Future<UserCredential> signInWithGoogleOnWeb(
  FirebaseAuth auth, {
  required Uri pageUri,
}) async {
  final options = auth.app.options;
  final provider = GoogleAuthProvider();
  if (options.projectId == 'cloud-board-development' &&
      pageUri.scheme == 'https' &&
      pageUri.host == options.authDomain) {
    // Firebase restores the redirect result during initialization after the
    // navigation. The existing auth-state stream then opens the signed-in app.
    await auth.signInWithRedirect(provider);
    return auth.getRedirectResult();
  }
  return auth.signInWithPopup(provider);
}
