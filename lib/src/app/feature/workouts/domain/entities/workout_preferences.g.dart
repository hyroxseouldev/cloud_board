// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkoutPreferences _$WorkoutPreferencesFromJson(Map<String, dynamic> json) =>
    _WorkoutPreferences(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      brandL: json['brandL'] as String? ?? 'CloudBoard',
      brandR: json['brandR'] as String? ?? '',
      soundTheme:
          $enumDecodeNullable(_$WorkoutSoundThemeEnumMap, json['soundTheme']) ??
          WorkoutSoundTheme.videoBeep,
      countdownSound:
          $enumDecodeNullable(_$WorkoutSoundEnumMap, json['countdownSound']) ??
          WorkoutSound.videoBeep,
      workStartSound:
          $enumDecodeNullable(_$WorkoutSoundEnumMap, json['workStartSound']) ??
          WorkoutSound.videoBeep,
      restStartSound:
          $enumDecodeNullable(_$WorkoutSoundEnumMap, json['restStartSound']) ??
          WorkoutSound.videoBeep,
      workoutEndSound:
          $enumDecodeNullable(_$WorkoutSoundEnumMap, json['workoutEndSound']) ??
          WorkoutSound.videoBeep,
      soundVolume: (json['soundVolume'] as num?)?.toDouble() ?? 1.0,
      countdown: json['countdown'] == null
          ? const CountdownPreferences()
          : CountdownPreferences.fromJson(
              json['countdown'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$WorkoutPreferencesToJson(_WorkoutPreferences instance) =>
    <String, dynamic>{
      'brandL': instance.brandL,
      'brandR': instance.brandR,
      'soundTheme': _$WorkoutSoundThemeEnumMap[instance.soundTheme]!,
      'countdownSound': _$WorkoutSoundEnumMap[instance.countdownSound]!,
      'workStartSound': _$WorkoutSoundEnumMap[instance.workStartSound]!,
      'restStartSound': _$WorkoutSoundEnumMap[instance.restStartSound]!,
      'workoutEndSound': _$WorkoutSoundEnumMap[instance.workoutEndSound]!,
      'soundVolume': instance.soundVolume,
      'countdown': instance.countdown.toJson(),
    };

const _$WorkoutSoundThemeEnumMap = {
  WorkoutSoundTheme.videoBeep: 'videoBeep',
  WorkoutSoundTheme.simple: 'simple',
  WorkoutSoundTheme.classic: 'classic',
  WorkoutSoundTheme.boxing: 'boxing',
  WorkoutSoundTheme.studio: 'studio',
  WorkoutSoundTheme.custom: 'custom',
};

const _$WorkoutSoundEnumMap = {
  WorkoutSound.silent: 'silent',
  WorkoutSound.gentleBeep: 'gentleBeep',
  WorkoutSound.classicBeep: 'classicBeep',
  WorkoutSound.sharpBeep: 'sharpBeep',
  WorkoutSound.lowPulse: 'lowPulse',
  WorkoutSound.boxingBell: 'boxingBell',
  WorkoutSound.softBell: 'softBell',
  WorkoutSound.doubleBeep: 'doubleBeep',
  WorkoutSound.longFinish: 'longFinish',
  WorkoutSound.videoBeep: 'videoBeep',
};
