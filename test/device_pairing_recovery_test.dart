import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'CloudBoard',
      packageName: 'fixture',
      version: '1.1.1',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  test('existing anonymous pairing repairs only missing reverse UID before heartbeat', () async {
    final db = _Database();
    final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
    final pairing = await source.issue(deviceId: 'local-id');
    expect(pairing.deviceId, 'tv');
    expect(db.read('users/owner/devices/tv/displayUid'), 'display');
    expect(db.transactions.take(2), [
      'users/owner/devices/tv/displayUid',
      'users/owner/devices/tv',
    ]);
    expect(db.read('users/owner/devices/tv/name'), 'Keep TV name');
    expect(db.read('users/owner/devices/tv/preferences'), {'volume': .5});
    expect(db.read('users/owner/devices/tv/preparationProtocol'), 1);
    expect(db.read('displayAccess/display'), {
      'ownerId': 'owner',
      'deviceId': 'tv',
      'pairingCode': '123456',
    });
    await source.issue(deviceId: 'local-id');
    expect(
      db.transactions.where((path) => path.endsWith('/displayUid')),
      hasLength(1),
    );
  });

  test(
    'interrupted repair resumes without reverification or replacing pairing',
    () async {
      final db = _Database()..failHeartbeatOnce = true;
      final source = DevicePairingRealtimeDataSource(db, _Auth(), 'owner');
      await expectLater(
        source.issue(deviceId: 'tv'),
        throwsA(isA<FirebaseException>()),
      );
      expect(db.read('users/owner/devices/tv/displayUid'), 'display');
      await source.issue(deviceId: 'tv');
      expect(db.read('users/owner/devices/tv/online'), isTrue);
      expect(
        db.transactions.where((path) => path.endsWith('/displayUid')),
        hasLength(1),
      );
    },
  );

  test(
    'simultaneous relaunch recovery converges on the same identity',
    () async {
      final db = _Database();
      await Future.wait([
        DevicePairingRealtimeDataSource(
          db,
          _Auth(),
          'owner',
        ).issue(deviceId: 'tv'),
        DevicePairingRealtimeDataSource(
          db,
          _Auth(),
          'owner',
        ).issue(deviceId: 'tv'),
      ]);
      expect(db.read('users/owner/devices/tv/displayUid'), 'display');
      expect(db.read('users/owner/devices/tv/pairingCode'), '123456');
    },
  );

  for (final change in [
    {'displayUid': 'another-display'},
    {'pairingCode': '654321'},
    {'paired': false},
    {'id': 'another-device'},
  ]) {
    test(
      'mismatched or revoked existing pairing cannot be repaired: $change',
      () async {
        final db = _Database();
        db.device.addAll(change);
        final before = Map<String, Object?>.from(db.device);
        await expectLater(
          DevicePairingRealtimeDataSource(
            db,
            _Auth(),
            'owner',
          ).issue(deviceId: 'tv'),
          throwsStateError,
        );
        expect(db.device, before);
        expect(db.transactions, isEmpty);
      },
    );
  }

  test('concurrent removal after UID repair never recreates a TV', () async {
    final db = _Database()..removeBeforeHeartbeat = true;
    await expectLater(
      DevicePairingRealtimeDataSource(
        db,
        _Auth(),
        'owner',
      ).issue(deviceId: 'tv'),
      throwsStateError,
    );
    expect(db.read('users/owner/devices/tv'), isNull);
  });

  test('another UID winning repair is not overwritten', () async {
    final db = _Database()..replaceBeforeRepair = true;
    await expectLater(
      DevicePairingRealtimeDataSource(
        db,
        _Auth(),
        'owner',
      ).issue(deviceId: 'tv'),
      throwsStateError,
    );
    expect(db.read('users/owner/devices/tv/displayUid'), 'another-display');
    expect(db.transactions, ['users/owner/devices/tv/displayUid']);
  });
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
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
            'online': true,
            'lastSeenAtMs': 1,
            'name': 'Keep TV name',
            'preferences': {'volume': .5},
          },
        },
      },
    },
  };
  final transactions = <String>[];
  bool failHeartbeatOnce = false,
      removeBeforeHeartbeat = false,
      replaceBeforeRepair = false;
  int events = 0;
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
  DatabaseReference push() => child('event-${db.events++}');
  @override
  Future<DataSnapshot> get() async {
    final value = db.read(path);
    return _Snapshot(value is Map ? Map<String, dynamic>.from(value) : value);
  }

  @override
  Future<void> set(Object? value) async => db.write(path, value);
  @override
  OnDisconnect onDisconnect() => _Disconnect();
  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler handler, {
    bool applyLocally = true,
  }) async {
    db.transactions.add(path);
    if (path.endsWith('/displayUid') && db.replaceBeforeRepair) {
      db.write(path, 'another-display');
    }
    if (path == 'users/owner/devices/tv') {
      if (db.failHeartbeatOnce) {
        db.failHeartbeatOnce = false;
        throw FirebaseException(
          plugin: 'firebase_database',
          code: 'unavailable',
        );
      }
      if (db.removeBeforeHeartbeat) db.write(path, null);
    }
    // Native transactions may first see a cold null cache, then server state.
    handler(null);
    final transaction = handler(db.read(path));
    if (!transaction.aborted) db.write(path, transaction.value);
    return _Result(!transaction.aborted, db.read(path));
  }
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
  @override
  Future<void> cancel() async {}
  @override
  Future<void> update(Map<String, Object?> value) async {}
  @override
  Future<void> set(Object? value, [Object? priority]) async {}
}
