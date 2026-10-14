import 'package:flutter/foundation.dart';
import 'package:cloud_board/src/app/core/services/installed_app_info.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/device/domain/usecases/display_presence_coordinator.dart';

import 'package:cloud_board/src/app/core/services/realtime_connection.dart'
    show waitForPlaybackConnection;
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';

class DevicePairingRealtimeDataSource {
  DevicePairingRealtimeDataSource(this._database, this._auth, this._ownerId);

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  final String? _ownerId;
  DisplayPresenceCoordinator? _presence;
  String? _presenceDevice;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _presence?.dispose();
  }

  DatabaseReference get _root => _database.ref();

  DatabaseReference get _ownerRef {
    final ownerId = _ownerId;
    if (ownerId == null) throw StateError('연결된 매장을 찾을 수 없습니다.');
    return _database.ref('users/$ownerId');
  }

  Future<void> _connected() => waitForPlaybackConnection(
    _database
        .ref('.info/connected')
        .onValue
        .map((event) => event.snapshot.value == true),
  );

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
            return decodeDisplayDevice(
              entry.key.toString(),
              entry.value as Map,
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
    await _connected();
    final owner = _auth.currentUser;
    if (owner == null || owner.isAnonymous) {
      throw StateError('매장 계정 로그인이 필요합니다.');
    }
    final normalizedCode = code.replaceAll(RegExp(r'\D'), '');
    if (normalizedCode.length != 6) {
      throw const FormatException('6자리 연결 코드를 입력해 주세요.');
    }
    // Retrying a claim whose response was lost must not register a second TV
    // or overwrite the name of an already registered device.
    final existing = await _ownerRef.child('devices').get();
    if (existing.value is Map &&
        (existing.value as Map).values.any(
          (item) =>
              isRegisteredDisplay(item) &&
              (item as Map)['pairingCode'] == normalizedCode,
        )) {
      return;
    }
    final globalPairing = await _database
        .ref('pairingCodes/$normalizedCode')
        .get();
    if (globalPairing.exists) {
      final installation = await displayInstallationInfo();
      await FirebaseFunctions.instanceFor(
            app: _auth.app,
            region: 'asia-northeast3',
          )
          .httpsCallable(
            'pairDisplayConnection',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<void>({
            'code': normalizedCode,
            'name': name.trim(),
            'zoneName': zoneName.trim(),
            'operationId': _root.push().key!,
            'appVersion': installation['appVersion'] ?? '',
            'appBuild': installation['appBuild'] ?? '',
          });
      return;
    }
    final pilot = await _database
        .ref('legacyPilotAccess/${owner.uid}/validUntilMs')
        .get();
    if (pilot.value is! num ||
        (pilot.value as num) <= DateTime.now().millisecondsSinceEpoch) {
      throw StateError('Free 플랜을 사용하려면 휴대폰 인증을 완료해 주세요.');
    }
    await _claimLegacy(code: normalizedCode, name: name, zoneName: zoneName);
  }

  Future<void> unpair(String deviceId) async {
    await _connected();
    final current = (await _ownerRef.child('devices/$deviceId').get()).value;
    if (current == null) return;
    if (current is! Map || current['pairingCode'] is! String) {
      throw StateError('연결 정보를 확인하지 못했습니다. 목록을 새로 확인해 주세요.');
    }
    final expectedPairingCode = current['pairingCode'] as String;
    final installation = await displayInstallationInfo();
    await FirebaseFunctions.instanceFor(
          app: _auth.app,
          region: 'asia-northeast3',
        )
        .httpsCallable(
          'unpairDisplayConnection',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<void>({
          'deviceId': deviceId,
          'expectedPairingCode': expectedPairingCode,
          'operationId': _root.push().key!,
          'appVersion': installation['appVersion'] ?? '',
          'appBuild': installation['appBuild'] ?? '',
        });
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
    List<String> replaceDeviceIds = const [],
  }) async {
    await _connected();
    if (!const {'auto', 'standby', 'black'}.contains(displayState)) {
      throw ArgumentError.value(displayState, 'displayState');
    }
    final access =
        (await _database.ref('subscriptionAccess/$_ownerId').get()).value;
    if (access is Map &&
        (access['plan'] == 'free' ||
            access['plan'] == 'plus' ||
            access['plan'] == 'premium')) {
      try {
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(
              'cloudboardSetDisplayState',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 15),
              ),
            )
            .call<void>({
              'deviceId': deviceId,
              'displayState': displayState,
              'replaceDeviceIds': replaceDeviceIds,
            });
      } on FirebaseFunctionsException {
        rethrow;
      }
      return;
    }
    await _ownerRef.child('devices/$deviceId').update({
      'displayState': displayState,
      'lastCommandAtMs': ServerValue.timestamp,
    });
  }

  Future<void> identify(String deviceId, String nonce, int expiresAtMs) async {
    await _connected();
    final result = await _ownerRef.child('devices/$deviceId').runTransaction((
      value,
    ) {
      if (value == null) return Transaction.success(null);
      if (!isRegisteredDisplay(value)) return Transaction.abort();
      return Transaction.success({
        ...value as Map,
        'identificationId': nonce,
        'identificationExpiresAtMs': expiresAtMs,
        'identificationAck': null,
      });
    }, applyLocally: false);
    if (!result.committed || !result.snapshot.exists) {
      throw StateError('디스플레이 연결이 해제되었습니다. 목록을 새로 확인해 주세요.');
    }
  }

  Future<void> acknowledgeIdentification(String deviceId, String nonce) async {
    final result = await _ownerRef.child('devices/$deviceId').runTransaction((
      value,
    ) {
      if (value == null) return Transaction.success(null);
      if (!isRegisteredDisplay(value) ||
          (value as Map)['identificationId'] != nonce) {
        return Transaction.abort();
      }
      return Transaction.success({
        ...value,
        'identificationAck': nonce,
        'online': true,
        'lastSeenAtMs': ServerValue.timestamp,
      });
    }, applyLocally: false);
    if (!result.committed) throw StateError('TV 확인 요청이 변경되었습니다.');
  }

  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) async {
    final result = await _ownerRef.child('devices/$deviceId').runTransaction((
      current,
    ) {
      if (current == null) return Transaction.success(null);
      if (_disposed ||
          current is! Map ||
          !isRegisteredDisplay(current) ||
          current['id'] != deviceId) {
        return Transaction.abort();
      }
      return Transaction.success({
        ...current,
        'currentSessionId': sessionId,
        'acknowledgedRevision': revision,
      });
    }, applyLocally: false);
    if (!result.committed || !result.snapshot.exists) {
      throw StateError('디스플레이 연결이 변경되었습니다.');
    }
    await updateDisplayHeartbeat(_database, _ownerId!, deviceId, ready: true);
  }

  Future<void> _markOnline({
    required String ownerId,
    required String deviceId,
    required String pairingCode,
  }) async {
    if (_disposed) throw StateError('디스플레이 연결이 변경되었습니다.');
    if (_presenceDevice == deviceId &&
        _presence != null &&
        !_presence!.exhausted) {
      return _presence!.firstReady.timeout(const Duration(seconds: 20));
    }
    _presence?.dispose();
    _presenceDevice = deviceId;
    final uid = _auth.currentUser?.uid;
    final anonymous = _auth.currentUser?.isAnonymous == true;
    final deviceRef = _database.ref('users/$ownerId/devices/$deviceId');
    final installation = await displayInstallationInfo();
    bool sameIdentity() => !_disposed && _auth.currentUser?.uid == uid;
    final coordinator = DisplayPresenceCoordinator(
      newConnectionId: () => deviceRef.child('presence').push().key!,
      registerDisconnect: (id) async {
        if (!sameIdentity()) throw StateError('디스플레이 계정이 변경되었습니다.');
        // This one-shot hook belongs only to this physical connection. A late
        // disconnect cannot change the pointer or a newer connection's state.
        await deviceRef.child('presence/$id').onDisconnect().set({
          'online': false,
          'lastSeenAtMs': ServerValue.timestamp,
        });
      },
      verify: (id) async {
        if (!sameIdentity()) throw StateError('디스플레이 계정이 변경되었습니다.');
        await FirebaseFunctions.instanceFor(
              app: _auth.app,
              region: 'asia-northeast3',
            )
            .httpsCallable(
              'verifyDisplayConnection',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 10),
              ),
            )
            .call<Object?>({
              'deviceId': deviceId,
              'operationId': id,
              'connectionId': id,
              'appVersion': installation['appVersion'] ?? '',
              'appBuild': installation['appBuild'] ?? '',
            });
      },
      publish: (id, isCurrent) async {
        final result = await deviceRef.runTransaction((current) {
          if (!sameIdentity() || !isCurrent()) return Transaction.abort();
          if (current == null) return Transaction.success(null);
          if (current is! Map ||
              !isRegisteredDisplay(current) ||
              current['pairingCode'] != pairingCode ||
              (anonymous && current['displayUid'] != uid)) {
            return Transaction.abort();
          }
          final presence = current['presence'] is Map
              ? Map<Object?, Object?>.from(current['presence'] as Map)
              : <Object?, Object?>{};
          presence[id] = {
            'online': true,
            'lastSeenAtMs': ServerValue.timestamp,
          };
          return Transaction.success({
            ...current,
            'presence': presence,
            'currentConnectionId': id,
            'presenceProtocol': 1,
            'online': true,
            'lastSeenAtMs': ServerValue.timestamp,
            'onlineSinceMs': ServerValue.timestamp,
            'playbackProtocol': 5,
            'preparationProtocol': anonymous ? 1 : 0,
            ...installation,
          });
        }, applyLocally: false);
        if (!result.committed || !result.snapshot.exists) {
          throw StateError('디스플레이 연결이 해제되었거나 변경되었습니다.');
        }
      },
    );
    _presence = coordinator;
    coordinator.start(
      _database
          .ref('.info/connected')
          .onValue
          .map((event) => event.snapshot.value == true),
    );
    await coordinator.firstReady.timeout(const Duration(seconds: 20));
  }

  Future<DevicePairing> _issueLegacy({required String deviceId}) async {
    final userRef = _ownerRef;
    final deviceRef = userRef.child('devices/$deviceId');
    final previousDevice = await deviceRef.get();
    final previousData = previousDevice.value is Map
        ? Map<String, dynamic>.from(previousDevice.value! as Map)
        : const <String, dynamic>{};
    final previousPairingCode = previousData['pairingCode'] as String?;
    if (isRegisteredDisplay(previousData) && previousPairingCode != null) {
      await _markOnline(
        ownerId: _ownerId!,
        deviceId: deviceId,
        pairingCode: previousPairingCode,
      );
      return DevicePairing(
        code: previousPairingCode,
        deviceId: deviceId,
        expiresAtMs: DateTime.now()
            .add(const Duration(days: 3650))
            .millisecondsSinceEpoch,
      );
    }
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

      final updates = <String, Object?>{
        'devices/$deviceId/id': deviceId,
        'devices/$deviceId/mode': 'display',
        'devices/$deviceId/pairingCode': code,
        'devices/$deviceId/pairingExpiresAtMs': expiresAtMs,
        'devices/$deviceId/online': false,
        'devices/$deviceId/lastSeenAtMs': ServerValue.timestamp,
        'devices/$deviceId/playbackProtocol': 5,
      };
      if (!previousDevice.exists) {
        updates['devices/$deviceId/displayState'] = 'auto';
      }
      await userRef.update(updates);
      if (previousPairingCode != null && previousPairingCode != code) {
        await userRef.child('pairingCodes/$previousPairingCode').remove();
      }
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

Future<Map<String, Object>> displayInstallationInfo() async {
  try {
    final package = await readInstalledAppInfo().timeout(
      const Duration(seconds: 2),
    );
    return {
      'appVersion': package.version,
      'appBuild': package.buildNumber,
      'appPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
  } catch (_) {
    return const {};
  }
}

/// Heartbeats never create a deleted registration, restore paired=true, or move
/// the current connection pointer. Preparation ACKs may separately mark ready.
Future<void> updateDisplayHeartbeat(
  FirebaseDatabase database,
  String ownerId,
  String deviceId, {
  bool ready = false,
}) async {
  final deviceRef = database.ref('users/$ownerId/devices/$deviceId');
  final result = await deviceRef.runTransaction((current) {
    if (current == null) return Transaction.success(null);
    if (current is! Map ||
        !isRegisteredDisplay(current) ||
        current['id'] != deviceId) {
      return Transaction.abort();
    }
    final update = <Object?, Object?>{
      ...current,
      'lastSeenAtMs': ServerValue.timestamp,
    };
    if (current['presenceProtocol'] == 1) {
      final id = current['currentConnectionId'];
      final raw = current['presence'];
      if (id is! String ||
          raw is! Map ||
          raw[id] is! Map ||
          (raw[id] as Map)['online'] != true) {
        return Transaction.abort();
      }
      final presence = Map<Object?, Object?>.from(raw);
      presence[id] = {
        ...raw[id] as Map,
        'lastSeenAtMs': ServerValue.timestamp,
        if (ready) 'readyAtMs': ServerValue.timestamp,
      };
      update['presence'] = presence;
    }
    return Transaction.success(update);
  }, applyLocally: false);
  if (!result.committed || !result.snapshot.exists) {
    throw StateError('디스플레이 연결을 다시 확인해 주세요.');
  }
}

DisplayDevice decodeDisplayDevice(String deviceId, Map value) {
  final item = Map<String, dynamic>.from(value);
  final connectionId = item['currentConnectionId'] as String?;
  final connections = item['presence'];
  final presence = connections is Map && connections[connectionId] is Map
      ? connections[connectionId] as Map
      : const {};
  final usesScopedPresence = item['presenceProtocol'] == 1;
  final verification = item['connectionVerification'] is Map
      ? item['connectionVerification'] as Map
      : const {};
  final health = item['preparationHealth'] is Map
      ? item['preparationHealth'] as Map
      : const {};
  return DisplayDevice(
    id: (item['id'] as String?) ?? deviceId,
    name: (item['name'] as String?) ?? '연결 대기 디스플레이',
    zoneId: (item['zoneId'] as String?) ?? 'main',
    zoneName: (item['zoneName'] as String?) ?? '메인 구역',
    online: usesScopedPresence
        ? presence['online'] == true
        : item['online'] == true,
    connectionId: connectionId,
    verifiedConnectionId: verification['connectionId'] as String?,
    verifiedAtMs: (verification['verifiedAtMs'] as num?)?.toInt() ?? 0,
    readyAtMs: (presence['readyAtMs'] as num?)?.toInt() ?? 0,
    recoveryProtocol: (item['recoveryProtocol'] as num?)?.toInt() ?? 0,
    preparationHealth: DisplayPreparationHealth(
      stage: (health['stage'] as String?) ?? '',
      code: (health['code'] as String?) ?? '',
      attempt: (health['attempt'] as num?)?.toInt() ?? 0,
      checkedAtMs: (health['checkedAtMs'] as num?)?.toInt() ?? 0,
      requestId: health['requestId'] as String?,
    ),
    appVersion: (item['appVersion'] as String?) ?? '',
    appBuild: (item['appBuild'] as String?) ?? '',
    appPlatform: (item['appPlatform'] as String?) ?? '',
    playbackProtocol: (item['playbackProtocol'] as num?)?.toInt() ?? 1,
    preparationProtocol: (item['preparationProtocol'] as num?)?.toInt() ?? 0,
    lastSeenAtMs:
        ((usesScopedPresence ? presence['lastSeenAtMs'] : item['lastSeenAtMs'])
                as num?)
            ?.round() ??
        0,
    currentSessionId: item['currentSessionId'] as String?,
    acknowledgedRevision: (item['acknowledgedRevision'] as num?)?.round() ?? 0,
    paired: isRegisteredDisplay(item),
    pairingCode: (item['pairingCode'] as String?) ?? '',
    identificationId: item['identificationId'] as String?,
    identificationExpiresAtMs:
        (item['identificationExpiresAtMs'] as num?)?.round() ?? 0,
    identificationAck: item['identificationAck'] as String?,
    displayState: (item['displayState'] as String?) ?? 'auto',
    preferences: decodeDisplayPreferences(item['preferences']),
    lastCommandAtMs: (item['lastCommandAtMs'] as num?)?.round() ?? 0,
    onlineSinceMs: (item['onlineSinceMs'] as num?)?.round() ?? 0,
  );
}
