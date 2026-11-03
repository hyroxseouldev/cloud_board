// Run explicitly against demo-only local emulators. Uses the real FlutterFire
// web implementations and production rules, never a mock database messenger.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/display_preparation_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database_web/firebase_database_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real SDK heartbeat/health writes survive overlap and retain connection fences', () async {
    if (!const bool.fromEnvironment('HEARTBEAT_LOCAL_EMULATORS')) {
      throw StateError('Explicit local emulator opt-in required');
    }
    const project = 'demo-cloudboard-heartbeat';
    FirebaseCoreWeb.registerWith(webPluginRegistrar);
    FirebaseAuthWeb.registerWith(webPluginRegistrar);
    FirebaseDatabaseWeb.registerWith(webPluginRegistrar);
    webPluginRegistrar.registerMessageHandler();
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'local-only-key',
        appId: '1:1234567890:web:1234567890abcdef',
        messagingSenderId: '1234567890',
        projectId: project,
        authDomain: 'localhost',
        databaseURL: 'https://$project-default-rtdb.firebaseio.com',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 19699);
    final database = FirebaseDatabase.instanceFor(app: app);
    database.useDatabaseEmulator('127.0.0.1', 19600);
    final user = (await auth.signInAnonymously()).user!;
    Future<void> seed(String path, Object? value) async {
      final response = await http.put(
        Uri.parse('http://127.0.0.1:19600/$path.json?ns=$project-default-rtdb'),
        headers: {
          'Authorization': 'Bearer owner',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(value),
      );
      expect(response.statusCode, 200);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    const path = 'users/owner/devices/tv';
    final fixture = {
      'id': 'tv',
      'paired': true,
      'pairingCode': '123456',
      'displayUid': user.uid,
      'preparationHealth': {
        'stage': 'heartbeat',
        'code': 'aborted',
        'attempt': 1,
        'checkedAtMs': now,
      },
      'mode': 'display',
      'name': 'Fixture TV',
      'online': true,
      'lastSeenAtMs': now,
      'presenceProtocol': 1,
      'currentConnectionId': 'current',
      'presence': {
        'current': {'online': true, 'lastSeenAtMs': now},
      },
      'connectionVerification': {
        'connectionId': 'current',
        'verifiedAtMs': now,
        'protocol': 1,
      },
    };
    await seed('', {
      'users': {
        'owner': {
          'devices': {'tv': fixture},
        },
      },
      'displayAccess': {
        user.uid: {
          'ownerId': 'owner',
          'deviceId': 'tv',
          'pairingCode': '123456',
        },
      },
      'subscriptionAccess': {
        'owner': {'plan': 'premium', 'validUntilMs': now + 600000},
      },
    });
    final source = DisplayPreparationDataSource(database, 'owner');
    final device = database.ref(path);
    // No SDK read first: error clearing must work with an empty local cache.
    await source.reportHealth(
      'tv',
      stage: 'heartbeat',
      connectionId: 'current',
    );
    expect(
      ((await device.get()).value as Map).containsKey('preparationHealth'),
      isFalse,
    );
    await source.heartbeat(
      'tv',
      connectionId: 'current',
      policy: DisplayHeartbeatPolicy.target,
    );
    expect(
      ((await device.get()).value as Map)['heartbeatPolicy'],
      containsPair('heartbeatIntervalSeconds', 60),
    );

    // Reproduce the original conflict with the real SDK, using the old set path.
    await database.goOffline();
    Object? legacyError;
    final legacy = device
        .runTransaction(
          (value) => Transaction.success(value),
          applyLocally: false,
        )
        .then<void>(
          (_) {},
          onError: (Object error) {
            legacyError = error;
          },
        );
    final legacyHealth = device.child('preparationHealth').set({
      'stage': 'heartbeat',
      'code': 'aborted',
      'attempt': 1,
      'checkedAtMs': ServerValue.timestamp,
    });
    await database.goOnline();
    await Future.wait([legacy, legacyHealth]);
    expect(legacyError, isA<FirebaseException>());
    debugPrint(
      'Legacy transaction/set conflict: ${(legacyError as FirebaseException).code}',
    );

    // Actual candidate datasource: several timed-out callers share one native
    // heartbeat; health writes do not cancel it; ready is a separate write.
    await database.goOffline();
    final pending = source.heartbeat('tv', connectionId: 'current');
    await expectLater(
      pending.timeout(const Duration(milliseconds: 30)),
      throwsA(isA<TimeoutException>()),
    );
    final retry = source.heartbeat('tv', connectionId: 'current');
    final ready = source.heartbeat('tv', connectionId: 'current', ready: true);
    final health = source.reportHealth(
      'tv',
      stage: 'heartbeat',
      code: 'aborted',
      attempt: 4,
    );
    await database.goOnline();
    await Future.wait([pending, retry, ready, health])
        .timeout(const Duration(seconds: 15));
    await source.reportHealth(
      'tv',
      stage: 'heartbeat',
      connectionId: 'current',
    );
    var saved = (await device.get()).value as Map;
    expect((saved['presence'] as Map)['current']['readyAtMs'], isA<num>());
    expect(saved.containsKey('preparationHealth'), isFalse);
    expect(saved['currentConnectionId'], 'current');
    await source.reportHealth(
      'tv',
      stage: 'media',
      code: 'unavailable',
      connectionId: 'current',
    );
    await source.reportHealth(
      'tv',
      stage: 'heartbeat',
      connectionId: 'current',
    );
    await source.reportHealth(
      'tv',
      stage: 'heartbeat',
      code: 'aborted',
      connectionId: 'old',
    );
    saved = (await device.get()).value as Map;
    expect((saved['preparationHealth'] as Map)['stage'], 'media');
    await source.reportHealth('tv', stage: 'media', connectionId: 'current');

    await expectLater(
      updateDisplayHeartbeat(database, 'owner', 'tv', connectionId: 'old'),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.message,
          'reason',
          'heartbeat_connection_changed',
        ),
      ),
    );
    await seed('$path/presence/current/online', false);
    await expectLater(
      source.heartbeat('tv', connectionId: 'current'),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.message,
          'reason',
          'heartbeat_presence_offline',
        ),
      ),
    );
    saved = (await device.get()).value as Map;
    expect((saved['presence'] as Map)['current']['online'], isFalse);
    await auth.signOut();
    await app.delete();
  }, timeout: const Timeout(Duration(seconds: 90)));
}
