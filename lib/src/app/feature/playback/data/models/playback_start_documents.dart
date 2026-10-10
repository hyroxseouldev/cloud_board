import 'package:firebase_database/firebase_database.dart';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

/// Wire documents shared by the real start transaction and rules contracts.
class PlaybackStartDocuments {
  PlaybackStartDocuments(PlaybackSessionModel model, {required bool split}) {
    state = model.toJson()..['anchorServerMs'] = ServerValue.timestamp;
    if (split) {
      state.remove('workoutSnapshot');
      state.addAll({
        'schemaVersion': 2,
        'snapshotId': model.id,
        'workoutId': model.workoutSnapshot['id'],
        'workoutName': model.workoutSnapshot['name'],
      });
      snapshot = {
        ...model.workoutSnapshot,
        '_storedAtMs': ServerValue.timestamp,
      };
    }
  }

  late final Map<String, dynamic> state;
  Map<String, dynamic>? snapshot;
}
