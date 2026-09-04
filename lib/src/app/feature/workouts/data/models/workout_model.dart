import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/workout.dart';

part 'workout_model.g.dart';

@JsonSerializable(explicitToJson: true)
class WorkoutModel {
  const WorkoutModel({
    required this.id,
    required this.ownerId,
    required this.author,
    required this.name,
    required this.folder,
    required this.brandL,
    required this.brandR,
    required this.modules,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, ownerId, name, folder, brandL, brandR;
  final WorkoutAuthorModel author;
  final List<WorkoutModuleModel> modules;
  @FirestoreTimestampConverter()
  final DateTime createdAt;
  @FirestoreTimestampConverter()
  final DateTime updatedAt;
  factory WorkoutModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutModelToJson(this);
  Workout toEntity() => Workout(
    id: id,
    ownerId: ownerId,
    author: author.toEntity(),
    name: name,
    folder: folder,
    brandL: brandL,
    brandR: brandR,
    modules: modules.map((item) => item.toEntity()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  factory WorkoutModel.fromEntity(Workout value) => WorkoutModel(
    id: value.id,
    ownerId: value.ownerId,
    author: WorkoutAuthorModel.fromEntity(value.author),
    name: value.name,
    folder: value.folder,
    brandL: value.brandL,
    brandR: value.brandR,
    modules: value.modules.map(WorkoutModuleModel.fromEntity).toList(),
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );
}

@JsonSerializable()
class WorkoutAuthorModel {
  const WorkoutAuthorModel({
    required this.id,
    required this.displayName,
    required this.photoUrl,
  });

  final String id;
  final String displayName;
  final String? photoUrl;

  factory WorkoutAuthorModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutAuthorModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutAuthorModelToJson(this);

  WorkoutAuthor toEntity() =>
      WorkoutAuthor(id: id, displayName: displayName, photoUrl: photoUrl);

  factory WorkoutAuthorModel.fromEntity(WorkoutAuthor value) =>
      WorkoutAuthorModel(
        id: value.id,
        displayName: value.displayName,
        photoUrl: value.photoUrl,
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
    required this.imageUrl,
    required this.showTimer,
    required this.beep,
    required this.coverImage,
  });
  final String id, name, text, imageUrl;
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
    imageSource: imageUrl,
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
        imageUrl: value.imageSource,
        showTimer: value.showTimer,
        beep: value.beep,
        coverImage: value.coverImage,
      );
}

class FirestoreTimestampConverter implements JsonConverter<DateTime, Object?> {
  const FirestoreTimestampConverter();

  @override
  DateTime fromJson(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
    String isoDate => DateTime.parse(isoDate),
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };

  @override
  Object toJson(DateTime value) => Timestamp.fromDate(value);
}
