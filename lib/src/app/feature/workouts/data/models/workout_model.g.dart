// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkoutModel _$WorkoutModelFromJson(Map<String, dynamic> json) => WorkoutModel(
  id: json['id'] as String,
  name: json['name'] as String,
  folder: json['folder'] as String,
  brandL: json['brandL'] as String,
  brandR: json['brandR'] as String,
  modules: (json['modules'] as List<dynamic>)
      .map((e) => WorkoutModuleModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  updatedAt: (json['updatedAt'] as num).toInt(),
);

Map<String, dynamic> _$WorkoutModelToJson(WorkoutModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'folder': instance.folder,
      'brandL': instance.brandL,
      'brandR': instance.brandR,
      'modules': instance.modules.map((e) => e.toJson()).toList(),
      'updatedAt': instance.updatedAt,
    };

WorkoutModuleModel _$WorkoutModuleModelFromJson(Map<String, dynamic> json) =>
    WorkoutModuleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      workSeconds: (json['workSeconds'] as num).toInt(),
      sets: (json['sets'] as num).toInt(),
      restSeconds: (json['restSeconds'] as num).toInt(),
      text: json['text'] as String,
      imageBase64: json['imageBase64'] as String,
      showTimer: json['showTimer'] as bool,
      beep: json['beep'] as bool,
      coverImage: json['coverImage'] as bool,
    );

Map<String, dynamic> _$WorkoutModuleModelToJson(WorkoutModuleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'text': instance.text,
      'imageBase64': instance.imageBase64,
      'workSeconds': instance.workSeconds,
      'sets': instance.sets,
      'restSeconds': instance.restSeconds,
      'showTimer': instance.showTimer,
      'beep': instance.beep,
      'coverImage': instance.coverImage,
    };
