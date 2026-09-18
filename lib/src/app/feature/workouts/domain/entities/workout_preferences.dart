import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
part 'workout_preferences.freezed.dart';
part 'workout_preferences.g.dart';

@freezed
abstract class WorkoutPreferences with _$WorkoutPreferences {
  const WorkoutPreferences._();
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory WorkoutPreferences({
    @Default('CloudBoard') String brandL,
    @Default('') String brandR,
    @Default(WorkoutSoundTheme.videoBeep) WorkoutSoundTheme soundTheme,
    @Default(WorkoutSound.videoBeep) WorkoutSound countdownSound,
    @Default(WorkoutSound.videoBeep) WorkoutSound workStartSound,
    @Default(WorkoutSound.videoBeep) WorkoutSound restStartSound,
    @Default(WorkoutSound.videoBeep) WorkoutSound workoutEndSound,
    @Default(1.0) double soundVolume,
    @Default(CountdownPreferences()) CountdownPreferences countdown,
  }) = _WorkoutPreferences;
  factory WorkoutPreferences.fromJson(Map<String, dynamic> json) =>
      _$WorkoutPreferencesFromJson(json);
  factory WorkoutPreferences.fromWorkout(Workout value) => WorkoutPreferences(
    brandL: value.brandL,
    brandR: value.brandR,
    soundTheme: value.soundTheme,
    countdownSound: value.countdownSound,
    workStartSound: value.workStartSound,
    restStartSound: value.restStartSound,
    workoutEndSound: value.workoutEndSound,
    soundVolume: value.soundVolume,
    countdown: CountdownPreferences.fromWorkout(value),
  );
  Workout applyTo(Workout value) => countdown
      .applyTo(value)
      .copyWith(
        brandL: brandL,
        brandR: brandR,
        soundTheme: soundTheme,
        countdownSound: countdownSound,
        workStartSound: workStartSound,
        restStartSound: restStartSound,
        workoutEndSound: workoutEndSound,
        soundVolume: soundVolume.clamp(0, 1),
      );
}
