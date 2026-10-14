import 'dart:async';

import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// #61's recovery intent is retained through #176's server-owned repair. The
// real authorization/repair rules are exercised by display-recovery-emulator;
// this suite runs the real client source and callable transport, and verifies
// ordering/cancellation without restoring the unsafe direct UID mutation.
const _callable = BasicMessageChannel<Object?>(
  'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
  StandardMessageCodec(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database db;
  late Future<Object?> Function(Map parameters) verify;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(_callable, (message) async {
          final arguments = (message! as List).single as Map;
          expectSync(arguments['functionName'], 'verifyDisplayConnection');
          expectSync(arguments['region'], 'asia-northeast3');
          final parameters = arguments['parameters'] as Map;
          expectSync(parameters['deviceId'], 'tv');
          expectSync(parameters['connectionId'], parameters['operationId']);
          db.log.add('verify:${parameters['connectionId']}');
          try {
            return [await verify(parameters)];
          } on PlatformException catch (error) {
            return [error.code, error.message, error.details];
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
      final pairing = await pending;
      expectSync(pairing.deviceId, 'tv');
      expectSync(db.log, [
        'disconnect:users/owner/devices/tv/presence/event-0',
        'verify:event-0',
        'transaction:users/owner/devices/tv',
      ]);
      expectSync(db.device['displayUid'], 'display');
      expectSync(db.device['name'], 'Keep TV name');
      expectSync(db.device['preferences'], {'volume': .5});
      expectSync(db.device['preparationProtocol'], 1);
      expectSync(db.device['currentConnectionId'], 'event-0');
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
      source.dispose();
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
        throwsA(isA<TimeoutException>()),
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
  Completer<void>? disconnectBarrier;
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
      node[keys.last] = value;
    }
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
  Future<DataSnapshot> get() async => _Snapshot(db.read(path));
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
    expectSync(
      path,
      'users/owner/devices/tv',
      reason: 'The client never patches reverse UID separately.',
    );
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
    expectSync(value, {'online': false, 'lastSeenAtMs': ServerValue.timestamp});
    db.log.add('disconnect:$path');
    if (db.disconnectBarrier != null) await db.disconnectBarrier!.future;
  }
}
