import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_playback_snapshot.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

void main() {
  final original =
      Workout.empty(
        'w',
        const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
      ).copyWith(
        modules: [WorkoutModule.empty('slide')],
        brandL: 'Legacy',
        countdownSeconds: 12,
      );

  test('content document excludes all preferences but preserves slides and timestamps', () {
    final content = WorkoutContent.fromWorkout(original);
    final json = WorkoutDocument.encode(content);
    expect(WorkoutDocument.legacySettingKeys.any(json.containsKey), isFalse);
    expect(json['schemaVersion'], 2);
    final decoded = WorkoutDocument.decode(json).toEntity();
    expect(WorkoutContent.fromWorkout(decoded), content);
  });

  test('resolved settings never leak into content serialization', () {
    final content = WorkoutContent.fromWorkout(original);
    final settings = const WorkoutPreferences(brandL: 'New', revision: 9);
    final snapshot = WorkoutPlaybackSnapshot(
      content: content,
      settings: settings,
      usesAccountSettings: true,
    );
    final resolved = snapshot.toWorkout();
    expect(resolved.brandL, 'New');
    expect(original.brandL, 'Legacy');
    expect(
      WorkoutDocument.encode(WorkoutContent.fromWorkout(resolved)),
      WorkoutDocument.encode(content),
    );
    expect(settings.toJson().containsKey('revision'), isFalse);
    // Keep complete wire settings for legacy TVs; do not use content JSON here.
    final session = PlaybackSessionModel.fromWorkout(
      id: 's',
      ownerId: 'u',
      zoneId: 'main',
      targetDeviceIds: ['tv'],
      workout: resolved,
      stepIndex: 0,
      durationMs: 1000,
      deviceId: 'controller',
    );
    expect(session.toEntity().workout.brandL, 'New');
    expect(session.toEntity().workout.modules, original.modules);
  });

  test(
    'unknown content schema fails instead of silently changing playback',
    () {
      expect(
        () => WorkoutDocument.decode({'schemaVersion': 999}),
        throwsFormatException,
      );
    },
  );
}
