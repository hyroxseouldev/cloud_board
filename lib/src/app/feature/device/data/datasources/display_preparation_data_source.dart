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

  Stream<DisplayPreparation?> watchRequest() => _root
      .child('request')
      .onValue
      .map((e) => decodeDisplayPreparation(e.snapshot.value));
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
  Future<void> heartbeat(String deviceId) => database
      .ref('users/$ownerId/devices/$deviceId')
      .update({'lastSeenAtMs': ServerValue.timestamp, 'online': true});
}
