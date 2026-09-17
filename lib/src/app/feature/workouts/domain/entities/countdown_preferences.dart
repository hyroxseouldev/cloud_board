import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'countdown_preferences.freezed.dart';
part 'countdown_preferences.g.dart';

enum CountdownNumberFormat { seconds, clock }

@freezed
abstract class CountdownAppearance with _$CountdownAppearance {
  const factory CountdownAppearance({
    @Default(true) bool showReady,
    @Default(true) bool showTitle,
    @Default(1.0) double numberScale,
    @Default(CountdownNumberFormat.seconds) CountdownNumberFormat numberFormat,
    int? numberColor,
    @Default(false) bool numberShadow,
    @Default(true) bool overlayEnabled,
    double? overlayOpacity,
    int? overlayColor,
  }) = _CountdownAppearance;
  factory CountdownAppearance.fromJson(Map<String, dynamic> json) =>
      _$CountdownAppearanceFromJson(json);
}

@freezed
abstract class CountdownPreferences with _$CountdownPreferences {
  const CountdownPreferences._();
  // Freezed forwards this constructor annotation to the generated class.
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory CountdownPreferences({
    @Default(3) int seconds,
    @Default(0xFF000000) int backgroundColor,
    @Default('') String imageSource,
    @Default(CountdownAppearance()) CountdownAppearance appearance,
  }) = _CountdownPreferences;
  factory CountdownPreferences.fromJson(Map<String, dynamic> json) =>
      _$CountdownPreferencesFromJson(json);
  factory CountdownPreferences.fromWorkout(Workout workout) =>
      CountdownPreferences(
        seconds: workout.countdownSeconds,
        backgroundColor: workout.countdownBackgroundColor,
        imageSource: workout.countdownImageSource,
        appearance: workout.countdownAppearance,
      );
  Workout applyTo(Workout workout) => workout.copyWith(
    countdownSeconds: seconds.clamp(0, 60),
    countdownBackgroundColor: backgroundColor,
    countdownImageSource: imageSource,
    countdownAppearance: appearance.copyWith(
      numberScale: appearance.numberScale.clamp(.5, 1.8),
      overlayOpacity: appearance.overlayOpacity?.clamp(0, 1),
    ),
  );
}
