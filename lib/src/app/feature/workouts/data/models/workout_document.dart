import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';

/// Firestore-only schema; the legacy model remains the wire format for TVs.
class WorkoutDocument {
  static const schemaVersion = 2;
  static const contentKeys = {
    'id',
    'ownerId',
    'author',
    'name',
    'folder',
    'modules',
    'createdAt',
    'updatedAt',
  };
  static const legacySettingKeys = {
    'brandL',
    'brandR',
    'soundTheme',
    'countdownSound',
    'workStartSound',
    'restStartSound',
    'workoutEndSound',
    'soundVolume',
    'countdownSeconds',
    'countdownBackgroundColor',
    'countdownImageSource',
    'countdownAppearance',
  };

  static Map<String, dynamic> encode(WorkoutContent content) {
    final json = WorkoutModel.fromEntity(content.toWorkout()).toJson();
    return {
      'schemaVersion': schemaVersion,
      for (final key in contentKeys) key: json[key],
    };
  }

  static WorkoutModel decode(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != null && version != 1 && version != schemaVersion) {
      throw const FormatException('새 버전에서 저장한 워크아웃입니다. 앱을 업데이트해 주세요.');
    }
    if (version != schemaVersion) return WorkoutModel.fromJson(json);
    // Rendering bridge only. Settings are resolved separately at playback start.
    final defaults = const WorkoutPreferences().applyTo(
      Workout.empty(
        json['id'] as String,
        WorkoutAuthorModel.fromJson(Map<String, dynamic>.from(json['author']))
            .toEntity(),
      ),
    );
    return WorkoutModel.fromJson({
      ...WorkoutModel.fromEntity(defaults).toJson(),
      for (final key in contentKeys) key: json[key],
    });
  }
}
