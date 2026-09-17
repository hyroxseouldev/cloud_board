// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkoutSummaryModel _$WorkoutSummaryModelFromJson(Map<String, dynamic> json) =>
    WorkoutSummaryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      folder: json['folder'] as String,
      imageSource: json['imageSource'] as String,
      moduleCount: (json['moduleCount'] as num).toInt(),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      updatedAt: const FirestoreTimestampConverter().fromJson(
        json['updatedAt'],
      ),
    );

Map<String, dynamic> _$WorkoutSummaryModelToJson(
  WorkoutSummaryModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'folder': instance.folder,
  'imageSource': instance.imageSource,
  'moduleCount': instance.moduleCount,
  'durationSeconds': instance.durationSeconds,
  'updatedAt': const FirestoreTimestampConverter().toJson(instance.updatedAt),
};
