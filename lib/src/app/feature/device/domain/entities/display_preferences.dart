import 'package:freezed_annotation/freezed_annotation.dart';
part 'display_preferences.freezed.dart';

@freezed
abstract class DisplayPreferences with _$DisplayPreferences {
  const factory DisplayPreferences({
    @Default(false) bool enabled,
    @Default(false) bool cover,
    @Default(1.0) double zoom,
    @Default(0.0) double offsetX,
    @Default(0.0) double offsetY,
    @Default(0.0) double safeInset,
  }) = _DisplayPreferences;
}
