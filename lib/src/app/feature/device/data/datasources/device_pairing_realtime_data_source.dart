import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';

class DevicePairingRealtimeDataSource {
  const DevicePairingRealtimeDataSource(
    this._database,
    this._auth,
    this._ownerId,
  );

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  final String? _ownerId;

  DatabaseReference get _root => _database.ref();

  DatabaseReference get _ownerRef {
    final ownerId = _ownerId;
    if (ownerId == null) throw StateError('연결된 매장을 찾을 수 없습니다.');
    return _database.ref('users/$ownerId');
  }

  Future<DevicePairing> issue({required String deviceId}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('디스플레이 연결을 준비하지 못했습니다.');
    if (!user.isAnonymous) return _issueLegacy(deviceId: deviceId);
    final accessRef = _database.ref('displayAccess/${user.uid}');
    final accessSnapshot = await accessRef.get();
    final access = accessSnapshot.value is Map
        ? Map<String, dynamic>.from(accessSnapshot.value! as Map)
        : const <String, dynamic>{};
    final pairedOwnerId = access['ownerId'] as String?;
    final pairedDeviceId = (access['deviceId'] as String?) ?? deviceId;
    if (pairedOwnerId != null) {
      await _markOnline(
        ownerId: pairedOwnerId,
        deviceId: pairedDeviceId,
        pairingCode: (access['pairingCode'] as String?) ?? '000000',
      );
      return DevicePairing(
        code: (access['pairingCode'] as String?) ?? '000000',
        deviceId: pairedDeviceId,
        expiresAtMs: DateTime.now()
            .add(const Duration(days: 3650))
            .millisecondsSinceEpoch,
      );
    }

    final previousCode = access['pairingCode'] as String?;
    if (previousCode != null) {
      await _database.ref('pairingCodes/$previousCode').remove();
    }
    final expiresAtMs = DateTime.now()
        .add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generatePairingCode();
      final pairingRef = _database.ref('pairingCodes/$code');
      final result = await pairingRef.runTransaction((current) {
        if (current != null) return Transaction.abort();
        return Transaction.success({
          'code': code,
          'deviceId': deviceId,
          'displayUid': user.uid,
          'expiresAtMs': expiresAtMs,
          'claimed': false,
        });
      });
      if (!result.committed) continue;

      await accessRef.set({
        'deviceId': deviceId,
        'pairingCode': code,
        'expiresAtMs': expiresAtMs,
      });
      return DevicePairing(
        code: code,
        deviceId: deviceId,
        expiresAtMs: expiresAtMs,
      );
    }
    throw StateError('연결 코드를 만들지 못했습니다. 다시 시도해 주세요.');
  }

  Stream<List<DisplayDevice>> watchDevices() {
    if (_ownerId == null) return Stream.value(const []);
    return _ownerRef.child('devices').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <DisplayDevice>[];
      final devices =
          value.entries.where((entry) => isRegisteredDisplay(entry.value)).map((
            entry,
          ) {
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
              paired: isRegisteredDisplay(item),
              displayState: (item['displayState'] as String?) ?? 'auto',
              preferences: decodeDisplayPreferences(item['preferences']),
              lastCommandAtMs: (item['lastCommandAtMs'] as num?)?.round() ?? 0,
              onlineSinceMs: (item['onlineSinceMs'] as num?)?.round() ?? 0,
            );
          }).toList()..sort((a, b) => a.name.compareTo(b.name));
      return devices;
    });
  }

  Future<void> savePreferences(
    String deviceId,
    DisplayPreferences preferences,
  ) async {
    final result = await _ownerRef.child('devices/$deviceId').runTransaction((
      value,
    ) {
      if (value == null) return Transaction.success(null);
      if (value is! Map || value['id'] != deviceId) return Transaction.abort();
      return Transaction.success({
        ...value,
        'preferences': {
          'enabled': preferences.enabled,
          'cover': preferences.cover,
          'zoom': preferences.zoom.clamp(.8, 1.3),
          'offsetX': preferences.offsetX.clamp(-.1, .1),
          'offsetY': preferences.offsetY.clamp(-.1, .1),
          'safeInset': preferences.safeInset.clamp(0, .15),
        },
      });
    }, applyLocally: false);
    if (!result.committed || !result.snapshot.exists) {
      throw StateError('디스플레이 연결을 확인해 주세요.');
    }
  }

  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  }) async {
    final owner = _auth.currentUser;
    if (owner == null || owner.isAnonymous) {
      throw StateError('매장 계정 로그인이 필요합니다.');
    }
    final normalizedCode = code.replaceAll(RegExp(r'\D'), '');
    if (normalizedCode.length != 6) {
      throw const FormatException('6자리 연결 코드를 입력해 주세요.');
    }
    final access = await _database.ref('subscriptionAccess/${owner.uid}').get();
    if (access.value is Map && (access.value! as Map)['managed'] == true) {
      try {
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable('cloudboardPairDisplay')
            .call<void>({
              'code': normalizedCode,
              'name': name.trim(),
              'zoneName': zoneName.trim(),
            });
      } on FirebaseFunctionsException catch (error) {
        throw StateError(error.message ?? '디스플레이 연결을 완료하지 못했습니다.');
      }
      return;
    }
    final pairingRef = _database.ref('pairingCodes/$normalizedCode');
    final initialSnapshot = await pairingRef.get();
    if (!initialSnapshot.exists) {
      await _claimLegacy(code: normalizedCode, name: name, zoneName: zoneName);
      return;
    }
    _requireAvailablePairing(initialSnapshot.value);

    final pairing = Map<String, dynamic>.from(initialSnapshot.value! as Map);
    final deviceId = pairing['deviceId'] as String?;
    final displayUid = pairing['displayUid'] as String?;
    if (deviceId == null || displayUid == null) {
      throw StateError('연결 코드에 기기 정보가 없습니다. 디스플레이에서 새 코드를 만들어 주세요.');
    }
    await _root.update({
      'pairingCodes/$normalizedCode/claimed': true,
      'pairingCodes/$normalizedCode/claimedAtMs': ServerValue.timestamp,
      'pairingCodes/$normalizedCode/ownerId': owner.uid,
      'displayAccess/$displayUid/ownerId': owner.uid,
      'displayAccess/$displayUid/deviceId': deviceId,
      'displayAccess/$displayUid/pairingCode': normalizedCode,
      'displayAccess/$displayUid/pairedAtMs': ServerValue.timestamp,
      'users/${owner.uid}/devices/$deviceId': {
        'id': deviceId,
        'displayUid': displayUid,
        'mode': 'display',
        'name': name.trim().isEmpty ? '매장 디스플레이' : name.trim(),
        'zoneId': 'main',
        'zoneName': zoneName.trim().isEmpty ? '메인 구역' : zoneName.trim(),
        'paired': true,
        'pairedAtMs': ServerValue.timestamp,
        'pairingCode': normalizedCode,
        'online': true,
        'onlineSinceMs': ServerValue.timestamp,
        'lastSeenAtMs': ServerValue.timestamp,
        'displayState': 'auto',
      },
    });
  }

  Future<void> unpair(String deviceId) async {
    final deviceRef = _ownerRef.child('devices/$deviceId');
    final snapshot = await deviceRef.get();
    final value = snapshot.value;
    final updates = <String, Object?>{
      'users/${_ownerId!}/devices/$deviceId': null,
    };
    if (value is Map) {
      final code = value['pairingCode'];
      final displayUid = value['displayUid'];
      if (code is String) {
        updates[displayUid is String
                ? 'pairingCodes/$code'
                : 'users/$_ownerId/pairingCodes/$code'] =
            null;
      }
      if (displayUid is String) updates['displayAccess/$displayUid'] = null;
    }
    await _root.update(updates);
  }

  Future<void> rename({
    required String deviceId,
    required String name,
    required String zoneName,
  }) async {
    final cleanName = name.trim();
    final cleanZone = zoneName.trim();
    if (cleanName.isEmpty ||
        cleanZone.isEmpty ||
        cleanName.length > 60 ||
        cleanZone.length > 60) {
      throw ArgumentError('기기 이름과 구역 이름을 1~60자로 입력해 주세요.');
    }
    final result = await _ownerRef.child('devices/$deviceId').runTransaction((
      value,
    ) {
      // A cold local cache may be null; let the server retry with current data.
      if (value == null) return Transaction.success(null);
      if (value is! Map || value['id'] != deviceId) return Transaction.abort();
      return Transaction.success({
        ...value,
        'name': cleanName,
        'zoneName': cleanZone,
      });
    }, applyLocally: false);
    if (!result.committed || !result.snapshot.exists) {
      throw StateError('연결된 디스플레이를 찾을 수 없습니다.');
    }
  }

  Future<void> setDisplayState({
    required String deviceId,
    required String displayState,
  }) {
    if (!const {'auto', 'standby', 'black'}.contains(displayState)) {
      throw ArgumentError.value(displayState, 'displayState');
    }
    return _ownerRef.child('devices/$deviceId').update({
      'displayState': displayState,
      'lastCommandAtMs': ServerValue.timestamp,
    });
  }

  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) => _ownerRef.child('devices/$deviceId').update({
    'currentSessionId': sessionId,
    'acknowledgedRevision': revision,
    'lastSeenAtMs': ServerValue.timestamp,
    'online': true,
  });

  Future<void> _markOnline({
    required String ownerId,
    required String deviceId,
    required String pairingCode,
  }) async {
    final deviceRef = _database.ref('users/$ownerId/devices/$deviceId');
    final previousDevice = await deviceRef.get();
    final previousData = previousDevice.value is Map
        ? Map<String, dynamic>.from(previousDevice.value! as Map)
        : const <String, dynamic>{};
    final wasOnline = previousData['online'] == true;
    final previousOfflineEventKey =
        previousData['pendingOfflineEventKey'] as String?;
    final eventRef = _database.ref('users/$ownerId/operations/events');
    final onlineEvent = eventRef.push();
    final offlineEvent = eventRef.push();
    final updates = <String, Object?>{
      'id': deviceId,
      'mode': 'display',
      'pairingCode': pairingCode,
      'paired': true,
      'online': true,
      'lastSeenAtMs': ServerValue.timestamp,
      'pendingOfflineEventKey': offlineEvent.key,
      'playbackProtocol': 2,
    };
    if (!wasOnline) updates['onlineSinceMs'] = ServerValue.timestamp;
    await deviceRef.update(updates);
    if (!wasOnline) {
      await onlineEvent.set({
        'id': onlineEvent.key,
        'type': 'device_online',
        'occurredAtMs': ServerValue.timestamp,
        'deviceId': deviceId,
        'scheduled': false,
      });
    }
    if (previousOfflineEventKey != null) {
      await eventRef.child(previousOfflineEventKey).onDisconnect().cancel();
    }
    await deviceRef.onDisconnect().update({
      'online': false,
      'lastSeenAtMs': ServerValue.timestamp,
    });
    await offlineEvent.onDisconnect().set({
      'id': offlineEvent.key,
      'type': 'device_offline',
      'occurredAtMs': ServerValue.timestamp,
      'deviceId': deviceId,
      'scheduled': false,
    });
  }

  Future<DevicePairing> _issueLegacy({required String deviceId}) async {
    final userRef = _ownerRef;
    final deviceRef = userRef.child('devices/$deviceId');
    final previousDevice = await deviceRef.get();
    final previousData = previousDevice.value is Map
        ? Map<String, dynamic>.from(previousDevice.value! as Map)
        : const <String, dynamic>{};
    final previousPairingCode = previousData['pairingCode'] as String?;
    final previousOfflineEventKey =
        previousData['pendingOfflineEventKey'] as String?;
    final wasOnline = previousData['online'] == true;
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

      final onlineEvent = userRef.child('operations/events').push();
      final offlineEvent = userRef.child('operations/events').push();
      final updates = <String, Object?>{
        'devices/$deviceId/id': deviceId,
        'devices/$deviceId/mode': 'display',
        'devices/$deviceId/pairingCode': code,
        'devices/$deviceId/pairingExpiresAtMs': expiresAtMs,
        'devices/$deviceId/online': true,
        'devices/$deviceId/lastSeenAtMs': ServerValue.timestamp,
        'devices/$deviceId/pendingOfflineEventKey': offlineEvent.key,
        'devices/$deviceId/playbackProtocol': 2,
      };
      if (!wasOnline) {
        updates['devices/$deviceId/onlineSinceMs'] = ServerValue.timestamp;
        updates['operations/events/${onlineEvent.key}'] = {
          'id': onlineEvent.key,
          'type': 'device_online',
          'occurredAtMs': ServerValue.timestamp,
          'deviceId': deviceId,
          'scheduled': false,
        };
      }
      if (!previousDevice.exists) {
        updates['devices/$deviceId/displayState'] = 'auto';
      }
      await userRef.update(updates);
      if (previousPairingCode != null && previousPairingCode != code) {
        await userRef.child('pairingCodes/$previousPairingCode').remove();
      }
      if (previousOfflineEventKey != null) {
        await userRef
            .child('operations/events/$previousOfflineEventKey')
            .onDisconnect()
            .cancel();
      }
      await deviceRef.onDisconnect().update({
        'online': false,
        'lastSeenAtMs': ServerValue.timestamp,
      });
      await offlineEvent.onDisconnect().set({
        'id': offlineEvent.key,
        'type': 'device_offline',
        'occurredAtMs': ServerValue.timestamp,
        'deviceId': deviceId,
        'scheduled': false,
      });
      return DevicePairing(
        code: code,
        deviceId: deviceId,
        expiresAtMs: expiresAtMs,
      );
    }
    throw StateError('연결 코드를 만들지 못했습니다. 다시 시도해 주세요.');
  }

  Future<void> _claimLegacy({
    required String code,
    required String name,
    required String zoneName,
  }) async {
    final pairingRef = _ownerRef.child('pairingCodes/$code');
    final snapshot = await pairingRef.get();
    _requireAvailablePairing(snapshot.value);
    final pairing = Map<String, dynamic>.from(snapshot.value! as Map);
    final deviceId = pairing['deviceId'] as String?;
    if (deviceId == null) {
      throw StateError('연결 코드에 기기 정보가 없습니다. 디스플레이에서 새 코드를 만들어 주세요.');
    }
    await _ownerRef.update({
      'pairingCodes/$code/claimed': true,
      'pairingCodes/$code/claimedAtMs': ServerValue.timestamp,
      'devices/$deviceId/name': name.trim().isEmpty ? '매장 디스플레이' : name.trim(),
      'devices/$deviceId/zoneId': 'main',
      'devices/$deviceId/zoneName': zoneName.trim().isEmpty
          ? '메인 구역'
          : zoneName.trim(),
      'devices/$deviceId/paired': true,
      'devices/$deviceId/pairedAtMs': ServerValue.timestamp,
    });
  }
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

DisplayPreferences decodeDisplayPreferences(Object? raw) {
  final map = raw is Map ? raw : const {};
  double number(String key, double fallback, double min, double max) {
    final value = map[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  return DisplayPreferences(
    enabled: map['enabled'] == true,
    cover: map['cover'] == true,
    zoom: number('zoom', 1, .8, 1.3),
    offsetX: number('offsetX', 0, -.1, .1),
    offsetY: number('offsetY', 0, -.1, .1),
    safeInset: number('safeInset', 0, 0, .15),
  );
}

/// A claimed timestamp is migration evidence only when no explicit paired flag
/// exists. Pending code issuance / online presence never constitutes pairing.
bool isRegisteredDisplay(Object? value) {
  if (value is! Map) return false;
  if (value.containsKey('paired')) return value['paired'] == true;
  return value['pairedAtMs'] is num && (value['pairedAtMs'] as num) > 0;
}
