import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
part 'workout_summary_model.g.dart';

@JsonSerializable()
class WorkoutSummaryModel {
  const WorkoutSummaryModel({
    required this.id,
    required this.name,
    required this.folder,
    required this.imageSource,
    required this.moduleCount,
    required this.durationSeconds,
    required this.updatedAt,
  });
  final String id, name, folder, imageSource;
  final int moduleCount, durationSeconds;
  @FirestoreTimestampConverter()
  final DateTime updatedAt;
  factory WorkoutSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSummaryModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutSummaryModelToJson(this);
  factory WorkoutSummaryModel.fromEntity(WorkoutSummary value) =>
      WorkoutSummaryModel(
        id: value.id,
        name: value.name,
        folder: value.folder,
        imageSource: value.imageSource,
        moduleCount: value.moduleCount,
        durationSeconds: value.durationSeconds,
        updatedAt: value.updatedAt,
      );
  WorkoutSummary toEntity() => WorkoutSummary(
    id: id,
    name: name,
    folder: folder,
    imageSource: imageSource,
    moduleCount: moduleCount,
    durationSeconds: durationSeconds,
    updatedAt: updatedAt,
  );
}
