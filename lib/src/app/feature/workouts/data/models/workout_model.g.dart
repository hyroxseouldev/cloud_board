// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkoutModel _$WorkoutModelFromJson(Map<String, dynamic> json) => WorkoutModel(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String,
  author: WorkoutAuthorModel.fromJson(json['author'] as Map<String, dynamic>),
  name: json['name'] as String,
  folder: json['folder'] as String,
  brandL: json['brandL'] as String,
  brandR: json['brandR'] as String,
  modules: (json['modules'] as List<dynamic>)
      .map((e) => WorkoutModuleModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: const FirestoreTimestampConverter().fromJson(json['createdAt']),
  updatedAt: const FirestoreTimestampConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$WorkoutModelToJson(
  WorkoutModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'ownerId': instance.ownerId,
  'name': instance.name,
  'folder': instance.folder,
  'brandL': instance.brandL,
  'brandR': instance.brandR,
  'author': instance.author.toJson(),
  'modules': instance.modules.map((e) => e.toJson()).toList(),
  'createdAt': const FirestoreTimestampConverter().toJson(instance.createdAt),
  'updatedAt': const FirestoreTimestampConverter().toJson(instance.updatedAt),
};

WorkoutAuthorModel _$WorkoutAuthorModelFromJson(Map<String, dynamic> json) =>
    WorkoutAuthorModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
    );

Map<String, dynamic> _$WorkoutAuthorModelToJson(WorkoutAuthorModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'photoUrl': instance.photoUrl,
    };

WorkoutModuleModel _$WorkoutModuleModelFromJson(Map<String, dynamic> json) =>
    WorkoutModuleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      workSeconds: (json['workSeconds'] as num).toInt(),
      sets: (json['sets'] as num).toInt(),
      restSeconds: (json['restSeconds'] as num).toInt(),
      text: json['text'] as String,
      imageUrl: json['imageUrl'] as String,
      showTimer: json['showTimer'] as bool,
      beep: json['beep'] as bool,
      coverImage: json['coverImage'] as bool,
    );

Map<String, dynamic> _$WorkoutModuleModelToJson(WorkoutModuleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'text': instance.text,
      'imageUrl': instance.imageUrl,
      'workSeconds': instance.workSeconds,
      'sets': instance.sets,
      'restSeconds': instance.restSeconds,
      'showTimer': instance.showTimer,
      'beep': instance.beep,
      'coverImage': instance.coverImage,
    };
