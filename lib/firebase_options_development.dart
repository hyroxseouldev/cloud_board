// Public Firebase SDK configuration for the isolated development project.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

abstract final class DevelopmentFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Development Firebase is configured for iOS, Android/TV and web.',
      ),
    };
  }

  static const android = FirebaseOptions(
    messagingSenderId: "1339501332",
    projectId: "cloud-board-development",
    databaseURL: "https://cloud-board-development-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "cloud-board-development.firebasestorage.app",
    appId: "1:1339501332:android:1afe8ec27a953ed01ef001",
    apiKey: "AIzaSyBcFPbe756-fPhs2LH3GiFgGFdrvwrDPXA",
  );
  static const ios = FirebaseOptions(
    messagingSenderId: "1339501332",
    projectId: "cloud-board-development",
    databaseURL: "https://cloud-board-development-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "cloud-board-development.firebasestorage.app",
    appId: "1:1339501332:ios:56b1f0d4a67a4e0c1ef001",
    apiKey: "AIzaSyDkhOabPWS_B4MjwsGhP4o8wnpD-qbIMdE",
    iosClientId: "1339501332-d86si8mreofoot9rgpue5jck1c7sq5f9.apps.googleusercontent.com",
    iosBundleId: "com.sunmkim.cloudboard.dev",
  );
  static const web = FirebaseOptions(
    messagingSenderId: "1339501332",
    projectId: "cloud-board-development",
    databaseURL: "https://cloud-board-development-default-rtdb.asia-southeast1.firebasedatabase.app",
    storageBucket: "cloud-board-development.firebasestorage.app",
    appId: "1:1339501332:web:27bf9349aa15e8d31ef001",
    apiKey: "AIzaSyCzMtZzZS2HMQUF9uWMB3EGARaf6HeysxQ",
    authDomain: "cloud-board-development.firebaseapp.com",
  );
}
