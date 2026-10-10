// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exploration_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExplorationProgress _$ExplorationProgressFromJson(Map<String, dynamic> json) =>
    _ExplorationProgress(
      templateKey: json['templateKey'] as String? ?? 'basics',
      purpose: json['purpose'] as String? ?? 'exploring',
      pendingImport: json['pendingImport'] as bool? ?? false,
      completedTemplates:
          (json['completedTemplates'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$ExplorationProgressToJson(
  _ExplorationProgress instance,
) => <String, dynamic>{
  'templateKey': instance.templateKey,
  'purpose': instance.purpose,
  'pendingImport': instance.pendingImport,
  'completedTemplates': instance.completedTemplates,
  'events': instance.events,
};
