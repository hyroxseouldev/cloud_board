import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/playback_session_model.dart';

class PlaybackRealtimeDataSource {
  const PlaybackRealtimeDataSource(this._database, this._auth);

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  DatabaseReference get _active =>
      _database.ref('users/${_requireUserId()}/activeSession');

  Stream<PlaybackSessionModel?> watchActive() => _active.onValue.map((event) {
    final value = event.snapshot.value;
    if (value == null) return null;
    return PlaybackSessionModel.fromJson(_stringMap(value));
  });

  Stream<int> watchServerTimeOffset() => _database
      .ref('.info/serverTimeOffset')
      .onValue
      .map((event) => (event.snapshot.value as num?)?.round() ?? 0);

  Future<PlaybackSessionModel> start(PlaybackSessionModel model) async {
    final json = model.toJson()..['anchorServerMs'] = ServerValue.timestamp;
    await _active.set(json);
    final snapshot = await _active.get();
    return PlaybackSessionModel.fromJson(_stringMap(snapshot.value));
  }

  Future<void> update({
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
  }) async {
    await _active.runTransaction((current) {
      if (current == null) return Transaction.abort();
      final json = _stringMap(current);
      json['status'] = status;
      json['updatedByDeviceId'] = deviceId;
      json['revision'] = ((json['revision'] as num?)?.round() ?? 0) + 1;
      json['anchorServerMs'] = ServerValue.timestamp;
      if (stepIndex != null) json['stepIndex'] = stepIndex;
      if (remainingMs != null) json['remainingMs'] = remainingMs;
      return Transaction.success(json);
    });
  }

  String _requireUserId() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    return user.uid;
  }
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) throw const FormatException('재생 세션 형식이 올바르지 않습니다.');
  return value.map(
    (key, item) => MapEntry(key.toString(), _normalizeValue(item)),
  );
}

Object? _normalizeValue(Object? value) {
  if (value is Map) return _stringMap(value);
  if (value is List) return value.map(_normalizeValue).toList();
  return value;
}
