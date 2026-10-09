import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

/// The exact two documents committed atomically by the app. The rules contract
/// exporter uses this same boundary, so a new serialized field is tested in CI.
class WorkoutSaveDocuments {
  WorkoutSaveDocuments(
    WorkoutModel model, {
    required bool contentOnly,
    Map<String, dynamic>? previous,
  }) {
    final entity = model.toEntity();
    workout = WorkoutDocument.encode(WorkoutContent.fromWorkout(entity));
    if (!contentOnly) {
      workout.remove('schemaVersion');
      final defaults = model.toJson();
      for (final key in WorkoutDocument.legacySettingKeys) {
        workout[key] = previous != null ? previous[key] : defaults[key];
      }
    }
    summary = WorkoutSummaryModel.fromEntity(summarizeWorkout(entity)).toJson();
  }

  late final Map<String, dynamic> workout;
  late final Map<String, dynamic> summary;
}
