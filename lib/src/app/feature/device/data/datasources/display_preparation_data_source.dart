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
  }) async {
    final target = database.ref(
      'users/$ownerId/devices/$deviceId/preparationHealth',
    );
    if (stage != null && code == null) {
      // A successful heartbeat must not erase a media/response failure.
      await target.runTransaction(
        (value) => value is Map && value['stage'] == stage
            ? Transaction.success(null)
            : Transaction.abort(),
        applyLocally: false,
      );
      return;
    }
    await target.set(
      stage == null
          ? null
          : {
              'stage': stage,
              'code': code ?? 'unexpected',
              'attempt': attempt.clamp(1, 10),
              'checkedAtMs': ServerValue.timestamp,
              'requestId': ?requestId,
            },
    );
  }
}
