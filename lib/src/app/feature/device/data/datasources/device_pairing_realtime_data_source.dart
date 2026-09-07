import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';

class DevicePairingRealtimeDataSource {
  const DevicePairingRealtimeDataSource(this._database, this._auth);

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  DatabaseReference get _userRef {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    return _database.ref('users/${user.uid}');
  }

  Future<DevicePairing> issue({required String deviceId}) async {
    final userRef = _userRef;
    final deviceRef = userRef.child('devices/$deviceId');
    final previousDevice = await deviceRef.get();
    final previousPairingCode = switch (previousDevice.value) {
      final Map value => value['pairingCode'] as String?,
      _ => null,
    };
    final expiresAtMs = DateTime.now()
        .add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generatePairingCode();
      final pairingRef = userRef.child('pairingCodes/$code');
      final result = await pairingRef.runTransaction((current) {
        if (current != null) return Transaction.abort();
        return Transaction.success({
          'code': code,
          'deviceId': deviceId,
          'expiresAtMs': expiresAtMs,
          'claimed': false,
        });
      });
      if (!result.committed) continue;

      await deviceRef.update({
        'id': deviceId,
        'mode': 'display',
        'pairingCode': code,
        'pairingExpiresAtMs': expiresAtMs,
        'online': true,
        'lastSeenAtMs': ServerValue.timestamp,
      });
      if (previousPairingCode != null && previousPairingCode != code) {
        await userRef.child('pairingCodes/$previousPairingCode').remove();
      }
      await deviceRef.onDisconnect().update({
        'online': false,
        'lastSeenAtMs': ServerValue.timestamp,
      });
      return DevicePairing(
        code: code,
        deviceId: deviceId,
        expiresAtMs: expiresAtMs,
      );
    }
    throw StateError('연결 코드를 만들지 못했습니다. 다시 시도해 주세요.');
  }

  Stream<List<DisplayDevice>> watchDevices() =>
      _userRef.child('devices').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <DisplayDevice>[];
        final devices = value.entries.map((entry) {
          final item = Map<String, dynamic>.from(entry.value as Map);
          return DisplayDevice(
            id: (item['id'] as String?) ?? entry.key.toString(),
            name: (item['name'] as String?) ?? '연결 대기 디스플레이',
            zoneId: (item['zoneId'] as String?) ?? 'main',
            zoneName: (item['zoneName'] as String?) ?? '메인 구역',
            online: item['online'] == true,
            lastSeenAtMs: (item['lastSeenAtMs'] as num?)?.round() ?? 0,
            currentSessionId: item['currentSessionId'] as String?,
            acknowledgedRevision:
                (item['acknowledgedRevision'] as num?)?.round() ?? 0,
            paired: item['paired'] == true,
          );
        }).toList()..sort((a, b) => a.name.compareTo(b.name));
        return devices;
      });

  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  }) async {
    final normalizedCode = code.replaceAll(RegExp(r'\D'), '');
    if (normalizedCode.length != 6) {
      throw const FormatException('6자리 연결 코드를 입력해 주세요.');
    }
    final pairingRef = _userRef.child('pairingCodes/$normalizedCode');
    final initialSnapshot = await pairingRef.get();
    _requireAvailablePairing(initialSnapshot.value);

    final pairing = Map<String, dynamic>.from(initialSnapshot.value! as Map);
    final deviceId = pairing['deviceId'] as String?;
    if (deviceId == null) {
      throw StateError('연결 코드에 기기 정보가 없습니다. 디스플레이에서 새 코드를 만들어 주세요.');
    }
    try {
      await _userRef.update({
        'pairingCodes/$normalizedCode/claimed': true,
        'pairingCodes/$normalizedCode/claimedAtMs': ServerValue.timestamp,
        'devices/$deviceId/name': name.trim().isEmpty
            ? '매장 디스플레이'
            : name.trim(),
        'devices/$deviceId/zoneId': 'main',
        'devices/$deviceId/zoneName': zoneName.trim().isEmpty
            ? '메인 구역'
            : zoneName.trim(),
        'devices/$deviceId/paired': true,
        'devices/$deviceId/pairedAtMs': ServerValue.timestamp,
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError('코드가 만료되었거나 이미 사용되었습니다. 새 코드를 입력해 주세요.');
      }
      rethrow;
    }
  }

  Future<void> unpair(String deviceId) async {
    final deviceRef = _userRef.child('devices/$deviceId');
    final snapshot = await deviceRef.get();
    final value = snapshot.value;
    if (value is Map) {
      final code = value['pairingCode'];
      if (code is String) await _userRef.child('pairingCodes/$code').remove();
    }
    await deviceRef.remove();
  }

  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) => _userRef.child('devices/$deviceId').update({
    'currentSessionId': sessionId,
    'acknowledgedRevision': revision,
    'lastSeenAtMs': ServerValue.timestamp,
    'online': true,
  });
}

void _requireAvailablePairing(Object? current) {
  if (current is! Map) {
    throw StateError('연결 코드를 찾을 수 없습니다. 디스플레이의 최신 코드를 확인해 주세요.');
  }
  final value = Map<String, dynamic>.from(current);
  final expiresAtMs = (value['expiresAtMs'] as num?)?.round() ?? 0;
  if (value['claimed'] == true) {
    throw StateError('이미 사용된 연결 코드입니다. 디스플레이에서 새 코드를 만들어 주세요.');
  }
  if (expiresAtMs <= DateTime.now().millisecondsSinceEpoch) {
    throw StateError('만료된 연결 코드입니다. 디스플레이에서 새 코드를 만들어 주세요.');
  }
}
