import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_board/src/app/feature/device/data/models/display_preparation_model.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';

class DisplayPreparationDataSource {
  const DisplayPreparationDataSource(this.database, this.ownerId);
  final FirebaseDatabase database;
  final String ownerId;
  DatabaseReference get _root =>
      database.ref('users/$ownerId/displayPreparation');
  Future<void> request(DisplayPreparation value) => _root.update({
    'request': encodeDisplayPreparation(value),
    'responses': null,
  });
  Future<void> cancel(String sessionId) async {
    await _root.child('request').runTransaction((value) {
      if (value is! Map || value['sessionId'] != sessionId) {
        return Transaction.abort();
      }
      return Transaction.success(null);
    }, applyLocally: false);
  }

  Stream<DisplayPreparation?> watchRequest() =>
      _root.child('request').onValue.map((e) {
        final value = e.snapshot.value;
        final request = decodeDisplayPreparation(value);
        if (value != null && request == null) {
          throw const FormatException('Invalid preparation request');
        }
        return request;
      });
  Map<String, DisplayPreparationReceipt> _receipts(Object? value) =>
      value is Map
      ? {
          for (final entry in value.entries)
            entry.key.toString(): ?decodePreparationReceipt(entry.value),
        }
      : {};
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() =>
      _root.child('responses').onValue.map((e) => _receipts(e.snapshot.value));
  Future<DisplayPreparation?> current() async =>
      decodeDisplayPreparation((await _root.child('request').get()).value);
  Future<Map<String, DisplayPreparationReceipt>> receipts() async =>
      _receipts((await _root.child('responses').get()).value);
  Future<void> respond(
    String deviceId,
    DisplayPreparation request, {
    required bool ready,
    required int imageCount,
    required bool audioReady,
  }) => _root.child('responses/$deviceId').set({
    'sessionId': request.sessionId,
    'revision': request.revision,
    'manifestHash': request.manifestHash,
    'status': ready ? 'ready' : 'failed',
    'checkedAtMs': ServerValue.timestamp,
    'imageCount': imageCount,
    'audioReady': audioReady,
  });
  Future<void> heartbeat(
    String deviceId, {
    bool ready = false,
    DisplayHeartbeatPolicy? policy,
    String? connectionId,
  }) => updateDisplayHeartbeat(
    database,
    ownerId,
    deviceId,
    ready: ready,
    policy: policy,
    connectionId: connectionId,
  );

  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
    String? connectionId,
  }) async {
    final target = database.ref('users/$ownerId/devices/$deviceId');
    // A child set can abort the heartbeat's ancestor transaction. Transact on
    // the same device instead, and fence late health from an old connection.
    await target.runTransaction((current) {
      // The SDK may first call us with an empty cache. Let it fetch/retry;
      // aborting here would silently leave an existing server error uncleared.
      if (current == null) return Transaction.success(null);
      if (current is! Map ||
          !isRegisteredDisplay(current) ||
          current['id'] != deviceId ||
          (connectionId != null &&
              current['currentConnectionId'] != connectionId)) {
        return Transaction.abort();
      }
      final value = Map<Object?, Object?>.from(current);
      if (stage == null || code == null) {
        final health = current['preparationHealth'];
        if (stage != null && (health is! Map || health['stage'] != stage)) {
          return Transaction.abort();
        }
        value.remove('preparationHealth');
      } else {
        value['preparationHealth'] = {
          'stage': stage,
          'code': code,
          'attempt': attempt.clamp(1, 10),
          'checkedAtMs': ServerValue.timestamp,
          'requestId': ?requestId,
        };
      }
      return Transaction.success(value);
    }, applyLocally: false);
  }
}
