import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';

Map<String, dynamic> workoutPreferencesDocument(
  WorkoutPreferences preferences, {
  required bool contentOnly,
  Object? serverTimestamp,
}) => {
  'schemaVersion': 1,
  'revision': preferences.revision,
  'updatedAt': serverTimestamp ?? FieldValue.serverTimestamp(),
  'contentOnly': contentOnly,
  'preferences': preferences.toJson(),
};
