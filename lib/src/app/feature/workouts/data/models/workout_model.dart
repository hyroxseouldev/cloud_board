import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/workout.dart';

part 'workout_model.g.dart';

@JsonSerializable(explicitToJson: true)
class WorkoutModel {
  const WorkoutModel({
    required this.id,
    required this.name,
    required this.folder,
    required this.brandL,
    required this.brandR,
    required this.modules,
    required this.updatedAt,
  });
  final String id, name, folder, brandL, brandR;
  final List<WorkoutModuleModel> modules;
  final int updatedAt;
  factory WorkoutModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutModelToJson(this);
  Workout toEntity() => Workout(
    id: id,
    name: name,
    folder: folder,
    brandL: brandL,
    brandR: brandR,
    modules: modules.map((item) => item.toEntity()).toList(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
  );
  factory WorkoutModel.fromEntity(Workout value) => WorkoutModel(
    id: value.id,
    name: value.name,
    folder: value.folder,
    brandL: value.brandL,
    brandR: value.brandR,
    modules: value.modules.map(WorkoutModuleModel.fromEntity).toList(),
    updatedAt: value.updatedAt.millisecondsSinceEpoch,
  );
}

@JsonSerializable()
class WorkoutModuleModel {
  const WorkoutModuleModel({
    required this.id,
    required this.name,
    required this.workSeconds,
    required this.sets,
    required this.restSeconds,
    required this.text,
    required this.imageBase64,
    required this.showTimer,
    required this.beep,
    required this.coverImage,
  });
  final String id, name, text, imageBase64;
  final int workSeconds, sets, restSeconds;
  final bool showTimer, beep, coverImage;
  factory WorkoutModuleModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutModuleModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutModuleModelToJson(this);
  WorkoutModule toEntity() => WorkoutModule(
    id: id,
    name: name,
    workSeconds: workSeconds,
    sets: sets,
    restSeconds: restSeconds,
    text: text,
    imageBase64: imageBase64,
    showTimer: showTimer,
    beep: beep,
    coverImage: coverImage,
  );
  factory WorkoutModuleModel.fromEntity(WorkoutModule value) =>
      WorkoutModuleModel(
        id: value.id,
        name: value.name,
        workSeconds: value.workSeconds,
        sets: value.sets,
        restSeconds: value.restSeconds,
        text: value.text,
        imageBase64: value.imageBase64,
        showTimer: value.showTimer,
        beep: value.beep,
        coverImage: value.coverImage,
      );
}
