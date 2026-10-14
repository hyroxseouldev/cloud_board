import 'dart:async';

import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/hooks/use_display_preparation.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// #61's recovery intent is retained through #176's server-owned repair. The
// real authorization/repair rules are exercised by display-recovery-emulator;
// this suite runs the real client source and verifies the callable contract and
// ordering/cancellation without restoring the unsafe direct UID mutation. The
// native callable transport is exercised on VM.
const _callable = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
  StandardMessageCodec(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database db;
  late Future<Object?> Function(Map parameters) verify;
  late Future<Object?> Function(Map arguments) invoke;
  final originalFunctions = FirebaseFunctionsPlatform.instance;
  setUpAll(() {
    if (kIsWeb) {
      // Native Pigeon's Int64 encoding is unsupported by dart2js. Keep the
      // native transport contract on VM; replace only that boundary on Chrome.
      FirebaseFunctionsPlatform.instance = _WebFunctions(
        (arguments) => invoke(arguments),
      );
    }
  });
  tearDownAll(() {
    if (kIsWeb) FirebaseFunctionsPlatform.instance = originalFunctions;
  });
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'CloudBoard',
      packageName: 'fixture',
      version: '1.1.1',
      buildNumber: '3',
      buildSignature: '',
    );
    db = _Database();
    verify = (parameters) async {
      // Model only the server response/write boundary. Authorization cases are
      // separately covered by the real Functions/RTDB emulator suite.
      db.device['displayUid'] ??= 'display';
      db.device['connectionVerification'] = {
        'connectionId': parameters['connectionId'],
        'operationId': parameters['operationId'],
        'verifiedAtMs': 1000,
        'protocol': 1,
      };
      return {
        'ownerId': 'owner',
        'deviceId': 'tv',
        'status': 'verified',
        'verifiedAtMs': 1000,
        'recoveryProtocol': 1,
      };
    };
    invoke = (arguments) async {
      expectSync(arguments['functionName'], 'verifyDisplayConnection');
      expectSync(arguments['region'], 'asia-northeast3');
      expectSync(arguments['timeout'], 10000);
      final parameters = arguments['parameters'] as Map;
      expectSync(parameters['deviceId'], 'tv');
      expectSync(parameters['connectionId'], parameters['operationId']);
      db.log.add('verify:${parameters['connectionId']}');
      return verify(parameters);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(_callable, (message) async {
          try {
            return [await invoke((message! as List).single as Map)];
          } on PlatformException catch (error) {
            // Match the native FlutterFire envelope, whose details carry the
            // callable status separately from the Pigeon transport error code.
            return [
              error.code,
              error.message ?? 'Fixture callable failure',
              {
                'code': error.code,
                'message': error.message ?? 'Fixture callable failure',
                'additionalData': error.details,
              },
            ];
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(_callable, null);
    unawaited(db.connection.close());
  });

  testWidgets(
    'existing anonymous pairing awaits disconnect registration then server repair before presence',
    (tester) async {
      db.disconnectBarrier = Completer<void>();
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      final pending = source.issue(deviceId: 'local-id');
      await tester.pump();
      expectSync(db.log, [
        'disconnect:users/owner/devices/tv/presence/event-0',
      ]);
      expectSync(db.read('users/owner/devices/tv/displayUid'), isNull);
      db.disconnectBarrier!.complete();
      await tester.pump();
      expectSync(
        db.log.where((entry) => entry.startsWith('verify:')),
        ['verify:event-0'],
        reason:
            'The callable fixture must be reached before awaiting readiness',
      );
      final pairing = await pending;
      expectSync(pairing.deviceId, 'tv');
      expectSync(db.log, [
        'disconnect:users/owner/devices/tv/presence/event-0',
        'verify:event-0',
        'disconnect:users/owner/operations/events/event-0-offline',
        'transaction:users/owner/devices/tv',
      ]);
      expectSync(db.device['displayUid'], 'display');
      expectSync(db.device['name'], 'Keep TV name');
      expectSync(db.device['preferences'], {'volume': .5});
      expectSync(db.device['preparationProtocol'], 1);
      expectSync(db.device['currentConnectionId'], 'event-0');
      final online =
          db.read('users/owner/operations/events/event-0-online') as Map;
      expectSync(online['type'], 'device_online');
      expectSync(online['deviceName'], 'Keep TV name');
      expectSync(online['appVersion'], '1.1.1');
      expectSync(db.device['pendingOfflineEventKey'], 'event-0-offline');
      expectSync(db.read('displayAccess/display'), {
        'ownerId': 'owner',
        'deviceId': 'tv',
        'pairingCode': '123456',
      });
      await source.issue(deviceId: 'local-id');
      expectSync(
        db.log.where((line) => line.startsWith('verify:')),
        hasLength(1),
      );
      expectSync(db.transactions, ['users/owner/devices/tv']);
      source.dispose();
    },
  );

  testWidgets(
    'a failed presence publish retries with new server verification without replacing identity',
    (tester) async {
      db.failPublishOnce = true;
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      final pending = source.issue(deviceId: 'tv');
      await tester.pump();
      expectSync(db.device['displayUid'], 'display');
      await tester.pump(const Duration(seconds: 1));
      await pending;
      expectSync(db.log.where((line) => line.startsWith('verify:')), [
        'verify:event-0',
        'verify:event-1',
      ]);
      expectSync(db.device['pairingCode'], '123456');
      expectSync(db.device['currentConnectionId'], 'event-1');
      expectSync(
        db.transactions.where((path) => path.endsWith('/displayUid')),
        isEmpty,
      );
      source.dispose();
    },
  );

  testWidgets(
    'reconnect registers a new disconnect hook and revalidates the same pairing',
    (tester) async {
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      final pending = source.issue(deviceId: 'tv');
      await tester.pump();
      await pending;
      final oldDisconnect = Map<String, Object?>.from(db.disconnectWrites);
      db.connection.add(false);
      await tester.pump();
      db.connection.add(true);
      await tester.pump();
      expectSync(db.device['currentConnectionId'], 'event-1');
      expectSync(db.log.where((line) => line.startsWith('verify:')), [
        'verify:event-0',
        'verify:event-1',
      ]);
      expectSync(db.device['displayUid'], 'display');
      expectSync(db.device['pairingCode'], '123456');
      final recovered =
          db.read('users/owner/operations/events/event-1-online') as Map;
      expectSync(recovered['recoveryOfEventId'], 'event-0-offline');
      // A previous socket's delayed disconnect can append its own history and
      // close only its own presence entry, never the newly verified connection.
      oldDisconnect.forEach(db.write);
      expectSync(db.device['currentConnectionId'], 'event-1');
      expectSync((db.device['presence'] as Map)['event-1']['online'], isTrue);
      expectSync(db.device['pendingOfflineEventKey'], 'event-1-offline');
      source.dispose();
    },
  );

  testWidgets(
    'failed offline telemetry registration does not block verified presence',
    (tester) async {
      db.failOfflineEvent = true;
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      final pending = source.issue(deviceId: 'tv');
      await tester.pump();
      await pending;
      expectSync(db.device['currentConnectionId'], 'event-0');
      expectSync(db.device['online'], isTrue);
      expectSync(db.device['pendingOfflineEventKey'], isNull);
      source.dispose();
    },
  );

  testWidgets(
    'initial readiness emission joins unpaired code issuance before the access read completes',
    (tester) async {
      db.write('displayAccess/display', {'deviceId': 'tv'});
      db.write('users/owner/devices', <String, Object?>{});
      db.accessReadBarrier = Completer<void>();
      final fixture = _ReadinessFixture(db);
      final listener = fixture.container.listen(
        devicePairingControllerProvider,
        (_, _) {},
      );
      await tester.pumpAndSettle();
      expect(fixture.state.isLoading, isTrue);
      expect(
        db.accessReads,
        1,
        reason: 'initial Loading→idle rebuild joins the same issue flight',
      );
      db.accessReadBarrier!.complete();
      await tester.pumpAndSettle();
      expect(
        fixture.state.hasValue &&
            !fixture.state.isLoading &&
            !fixture.state.hasError,
        isTrue,
      );
      final code = fixture.state.value.code as String;
      expect(
        db.transactions.where((path) => path.startsWith('pairingCodes/')),
        ['pairingCodes/$code'],
      );
      expect(db.accessWrites, 1);
      expect((db.read('displayAccess/display') as Map)['pairingCode'], code);
      expect(db.log.where((entry) => entry.startsWith('verify:')), isEmpty);
      listener.close();
      await fixture.close(tester);
    },
  );

  testWidgets(
    'current connection verification and publish gate real controller preparation after reconnect',
    (tester) async {
      final fixture = _ReadinessFixture(db);
      await fixture.mount(tester);
      expect(fixture.state.hasValue, isTrue);
      expect(fixture.preparation.subscriptions, 1);
      expect(fixture.preparation.heartbeats, 1);
      expect(db.log.where((e) => e.startsWith('verify:')), hasLength(1));
      final verified = verify;
      final gate = Completer<void>();
      db.publishBarrier = Completer<void>();
      verify = (parameters) async {
        await gate.future;
        return verified(parameters);
      };
      db.connection.add(false);
      await tester.pumpAndSettle();
      expect(fixture.state.isLoading, isTrue);
      db.connection.add(true);
      await tester.pumpAndSettle();
      expect(fixture.state.isLoading, isTrue);
      expect(fixture.preparation.subscriptions, 1);
      expect(fixture.preparation.heartbeats, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        fixture.state.isLoading,
        isTrue,
        reason: 'verification alone cannot bypass presence publish',
      );
      expect(fixture.preparation.heartbeats, 1);
      db.publishBarrier!.complete();
      await tester.pumpAndSettle();
      expect(
        fixture.state.hasValue &&
            !fixture.state.isLoading &&
            !fixture.state.hasError,
        isTrue,
      );
      expect(fixture.preparation.subscriptions, 2);
      expect(fixture.preparation.heartbeats, 2);
      expect(
        db.log.where((e) => e.startsWith('verify:')),
        hasLength(2),
        reason: 'controller rebuilds must join one coordinator',
      );
      await fixture.close(tester);
    },
  );

  for (final manual in [false, true]) {
    testWidgets(
      'reconnect permission denial stays blocked until ${manual ? 'explicit refresh' : 'a new connection'}',
      (tester) async {
        final fixture = _ReadinessFixture(db);
        await fixture.mount(tester);
        final verified = verify;
        verify = (_) async => throw PlatformException(
          code: 'permission-denied',
          message: 'private failure',
        );
        db.connection.add(false);
        await tester.pumpAndSettle();
        db.connection.add(true);
        await tester.pumpAndSettle();
        expect(fixture.state.hasError, isTrue);
        expect(fixture.preparation.subscriptions, 1);
        expect(fixture.preparation.heartbeats, 1);
        expect(
          fixture.diagnostics.events.single.context['action'],
          'pairing.verify',
        );
        expect(
          fixture.diagnostics.events.single.context['firebaseCode'],
          'permission-denied',
        );
        await tester.pump(const Duration(seconds: 40));
        await tester.pumpAndSettle();
        expect(db.log.where((e) => e.startsWith('verify:')), hasLength(2));
        expect(fixture.state.hasError, isTrue);
        verify = verified;
        if (manual) {
          unawaited(
            fixture.container
                .read(devicePairingControllerProvider.notifier)
                .refresh(),
          );
        } else {
          db.connection.add(false);
          await tester.pumpAndSettle();
          db.connection.add(true);
        }
        await tester.pumpAndSettle();
        expect(
          fixture.state.hasValue &&
              !fixture.state.isLoading &&
              !fixture.state.hasError,
          isTrue,
        );
        expect(fixture.preparation.subscriptions, 2);
        expect(fixture.preparation.heartbeats, 2);
        expect(db.log.where((e) => e.startsWith('verify:')), hasLength(3));
        await fixture.close(tester);
      },
    );
  }

  testWidgets(
    'stale reconnect success cannot unblock a newer connection verification',
    (tester) async {
      final fixture = _ReadinessFixture(db);
      await fixture.mount(tester);
      final verified = verify;
      final old = Completer<void>(), current = Completer<void>();
      verify = (parameters) async {
        await (parameters['connectionId'] == 'event-1'
            ? old.future
            : current.future);
        return verified(parameters);
      };
      db.connection.add(false);
      await tester.pumpAndSettle();
      db.connection.add(true);
      await tester.pumpAndSettle();
      db.connection.add(false);
      await tester.pumpAndSettle();
      db.connection.add(true);
      await tester.pumpAndSettle();
      old.complete();
      await tester.pumpAndSettle();
      expect(fixture.state.isLoading, isTrue);
      expect(fixture.preparation.subscriptions, 1);
      expect(fixture.preparation.heartbeats, 1);
      expect(db.device['currentConnectionId'], 'event-0');
      current.complete();
      await tester.pumpAndSettle();
      expect(
        fixture.state.hasValue &&
            !fixture.state.isLoading &&
            !fixture.state.hasError,
        isTrue,
      );
      expect(db.device['currentConnectionId'], 'event-2');
      expect(fixture.preparation.subscriptions, 2);
      expect(fixture.preparation.heartbeats, 2);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'reconnect transport retry exhaustion remains blocked without an automatic controller restart',
    (tester) async {
      final fixture = _ReadinessFixture(db);
      await fixture.mount(tester);
      verify = (_) async => throw PlatformException(code: 'unavailable');
      db.connection.add(false);
      await tester.pumpAndSettle();
      db.connection.add(true);
      await tester.pumpAndSettle();
      for (final seconds in [1, 2, 4, 8, 16]) {
        await tester.pump(Duration(seconds: seconds));
        await tester.pumpAndSettle();
      }
      expect(fixture.state.hasError, isTrue);
      expect(db.log.where((e) => e.startsWith('verify:')), hasLength(7));
      await tester.pump(const Duration(seconds: 40));
      await tester.pumpAndSettle();
      expect(db.log.where((e) => e.startsWith('verify:')), hasLength(7));
      expect(fixture.preparation.subscriptions, 1);
      expect(fixture.preparation.heartbeats, 1);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'server denial cannot publish presence or replace a foreign UID',
    (tester) async {
      db.device['displayUid'] = 'another-display';
      final before = Map<String, Object?>.from(db.device);
      verify = (_) async => throw PlatformException(
        code: 'failed-precondition',
        details: {'code': 'connection_conflict'},
      );
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      final failure = expectLater(
        source.issue(deviceId: 'tv'),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      await failure;
      expectSync(db.device, before);
      expectSync(db.transactions, isEmpty);
      source.dispose();
    },
  );

  testWidgets('removal after server verification never recreates the TV', (
    tester,
  ) async {
    db.removeBeforePublish = true;
    final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
    final failure = expectLater(
      source.issue(deviceId: 'tv'),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump();
    // Remaining server attempts also reject the deleted registration.
    verify = (_) async => throw PlatformException(
      code: 'failed-precondition',
      details: {'code': 'device_unpaired'},
    );
    await tester.pump(const Duration(seconds: 20));
    await failure;
    expectSync(db.read('users/owner/devices/tv'), isNull);
    expectSync(db.read('users/owner/operations/events'), isNull);
    expectSync(
      db.disconnectWrites.keys.where(
        (path) => path.contains('/operations/events/'),
      ),
      isEmpty,
    );
    expectSync(
      db.transactions.where((path) => path.endsWith('/displayUid')),
      isEmpty,
    );
    source.dispose();
  });

  testWidgets(
    'late server response after account disposal cannot publish online',
    (tester) async {
      final response = Completer<Object?>();
      verify = (_) => response.future;
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      final failure = expectLater(
        source.issue(deviceId: 'tv'),
        throwsStateError,
      );
      await tester.pump();
      source.dispose();
      response.complete({'status': 'verified'});
      await tester.pump(const Duration(seconds: 20));
      await failure;
      expectSync(db.transactions, isEmpty);
      expectSync(db.device['displayUid'], isNull);
    },
  );
}

class _WebFunctions extends FirebaseFunctionsPlatform {
  _WebFunctions(this.invoke, {FirebaseApp? app, String region = 'us-central1'})
    : super(app, region);

  final Future<Object?> Function(Map arguments) invoke;

  @override
  FirebaseFunctionsPlatform delegateFor({
    FirebaseApp? app,
    required String region,
  }) => _WebFunctions(invoke, app: app, region: region);

  @override
  HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) => _WebCallable(this, origin, name, options, invoke);
}

class _WebCallable extends HttpsCallablePlatform {
  _WebCallable(
    FirebaseFunctionsPlatform functions,
    String? origin,
    String name,
    HttpsCallableOptions options,
    this.invoke,
  ) : super(functions, origin, name, options, null);

  final Future<Object?> Function(Map arguments) invoke;

  @override
  Future<Object?> call([Object? parameters]) async {
    try {
      return await invoke({
        'functionName': name,
        'region': functions.region,
        'timeout': options.timeout.inMilliseconds,
        'parameters': parameters,
      });
    } on PlatformException catch (error) {
      throw FirebaseFunctionsException(
        code: error.code,
        message: error.message ?? 'Fixture callable failure',
        details: error.details,
      );
    }
  }
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  FirebaseApp get app => _App();
}

class _App extends Fake implements FirebaseApp {
  @override
  String get name => 'pairing-recovery-fixture';
}

class _User extends Fake implements User {
  @override
  String get uid => 'display';
  @override
  bool get isAnonymous => true;
}

class _Database extends Fake implements FirebaseDatabase {
  final Map<String, Object?> root = {
    'displayAccess': <String, Object?>{
      'display': <String, Object?>{
        'ownerId': 'owner',
        'deviceId': 'tv',
        'pairingCode': '123456',
      },
    },
    'users': <String, Object?>{
      'owner': <String, Object?>{
        'devices': <String, Object?>{
          'tv': <String, Object?>{
            'id': 'tv',
            'mode': 'display',
            'paired': true,
            'pairingCode': '123456',
            'online': false,
            'lastSeenAtMs': 1,
            'name': 'Keep TV name',
            'preferences': {'volume': .5},
          },
        },
      },
    },
  };
  final connection = StreamController<bool>.broadcast();
  final log = <String>[], transactions = <String>[];
  final disconnectWrites = <String, Object?>{};
  bool failOfflineEvent = false;
  Completer<void>? disconnectBarrier, publishBarrier, accessReadBarrier;
  int accessReads = 0, accessWrites = 0;
  bool failPublishOnce = false, removeBeforePublish = false;
  int serial = 0;
  Map get device => read('users/owner/devices/tv')! as Map;
  Object? read(String path) {
    Object? value = root;
    for (final key in path.split('/').where((key) => key.isNotEmpty)) {
      value = value is Map ? value[key] : null;
    }
    return value;
  }

  void write(String path, Object? value) {
    final keys = path.split('/');
    Map node = root;
    for (final key in keys.take(keys.length - 1)) {
      node = (node[key] ??= <String, Object?>{}) as Map;
    }
    if (value == null) {
      node.remove(keys.last);
    } else {
      node[keys.last] = _resolveServerValues(value);
    }
  }

  Object? _resolveServerValues(Object? value) {
    if (value is Map) {
      if (value['.sv'] == 'timestamp') return 1000;
      return {
        for (final entry in value.entries)
          entry.key: _resolveServerValues(entry.value),
      };
    }
    if (value is List) return value.map(_resolveServerValues).toList();
    return value;
  }

  @override
  DatabaseReference ref([String? path]) => _Reference(this, path ?? '');
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  String get key => path.split('/').last;
  @override
  DatabaseReference child(String path) => _Reference(db, '${this.path}/$path');
  @override
  DatabaseReference push() => child('event-${db.serial++}');
  @override
  Future<DataSnapshot> get() async {
    if (path == 'displayAccess/display') {
      db.accessReads++;
      await db.accessReadBarrier?.future;
    }
    return _Snapshot(db.read(path));
  }

  @override
  Future<void> set(Object? value) async {
    if (path == 'displayAccess/display') {
      db.accessWrites++;
    } else {
      expectSync(path, startsWith('users/owner/operations/events/'));
    }
    db.write(path, value);
  }

  @override
  Stream<DatabaseEvent> get onValue => Stream.multi((sink) {
    expectSync(path, '.info/connected');
    sink.add(_Event(true));
    final sub = db.connection.stream.listen((value) => sink.add(_Event(value)));
    sink.onCancel = sub.cancel;
  });
  @override
  OnDisconnect onDisconnect() => _Disconnect(db, path);
  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler handler, {
    bool applyLocally = true,
  }) async {
    db.transactions.add(path);
    db.log.add('transaction:$path');
    if (path.startsWith('pairingCodes/')) {
      final transaction = handler(db.read(path));
      if (!transaction.aborted) db.write(path, transaction.value);
      return _Result(!transaction.aborted, db.read(path));
    }
    expectSync(
      path,
      'users/owner/devices/tv',
      reason: 'The client never patches reverse UID separately.',
    );
    await db.publishBarrier?.future;
    if (db.failPublishOnce) {
      db.failPublishOnce = false;
      throw FirebaseException(plugin: 'firebase_database', code: 'unavailable');
    }
    if (db.removeBeforePublish) db.write(path, null);
    handler(null);
    final transaction = handler(db.read(path));
    if (!transaction.aborted) db.write(path, transaction.value);
    return _Result(!transaction.aborted, db.read(path));
  }
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
}

class _Result extends Fake implements TransactionResult {
  _Result(this.committed, Object? value) : snapshot = _Snapshot(value);
  @override
  final bool committed;
  @override
  final DataSnapshot snapshot;
}

class _Disconnect extends Fake implements OnDisconnect {
  _Disconnect(this.db, this.path);
  final _Database db;
  final String path;
  @override
  Future<void> set(Object? value, [Object? priority]) async {
    if (path.contains('/presence/')) {
      expectSync(value, {
        'online': false,
        'lastSeenAtMs': ServerValue.timestamp,
      });
    } else {
      expectSync(path, startsWith('users/owner/operations/events/'));
      expectSync((value as Map)['type'], 'device_offline');
      if (db.failOfflineEvent) throw StateError('telemetry unavailable');
    }
    db.log.add('disconnect:$path');
    if (db.disconnectBarrier != null) await db.disconnectBarrier!.future;
    db.disconnectWrites[path] = value;
  }

  @override
  Future<void> cancel() async => db.disconnectWrites.remove(path);
}

class _Diagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

class _PreparationProbe extends Fake implements DisplayPreparationRepository {
  int subscriptions = 0, heartbeats = 0;
  @override
  Stream<DisplayPreparation?> watchRequest(String deviceId) {
    subscriptions++;
    return Stream.value(null);
  }

  @override
  Future<void> heartbeat(String deviceId, {bool ready = false}) async {
    heartbeats++;
  }

  @override
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
  }) async {}
}

class _ReadinessHarness extends HookConsumerWidget {
  const _ReadinessHarness();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(devicePairingControllerProvider);
    useDisplayPreparation(
      context,
      ref,
      deviceId: 'tv',
      paired: pairing.hasValue && !pairing.isLoading && !pairing.hasError,
      standby: true,
      connected: true,
      foreground: true,
    );
    return const SizedBox();
  }
}

class _ReadinessFixture {
  _ReadinessFixture(_Database database)
    : source = DevicePairingRealtimeDataSource(database, _Auth(), 'owner');
  final DevicePairingRealtimeDataSource source;
  final preparation = _PreparationProbe();
  final diagnostics = _Diagnostics();
  late final container = ProviderContainer(
    overrides: [
      devicePairingActionsProvider.overrideWithValue(
        DevicePairingActions(DevicePairingRepositoryImpl(source)),
      ),
      deviceIdProvider.overrideWith((_) async => 'tv'),
      displayPreparationRepositoryProvider.overrideWithValue(preparation),
      serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
      errorReporterProvider.overrideWithValue(ErrorReporter(diagnostics)),
      operationTelemetryProvider.overrideWithValue(
        OperationTelemetry(readAccount: () => 'display', emit: (_, _) async {}),
      ),
    ],
  );
  AsyncValue<dynamic> get state =>
      container.read(devicePairingControllerProvider);
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _ReadinessHarness()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    source.dispose();
    await tester.pump();
  }
}
