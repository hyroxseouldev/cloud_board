import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'ai_slides.freezed.dart';

@freezed
abstract class AiSlidesAccess with _$AiSlidesAccess {
  const factory AiSlidesAccess({
    required bool premium,
    required bool enabled,
    required int remaining,
    required int limit,
  }) = _AiSlidesAccess;
}

@freezed
abstract class AiSlideDraft with _$AiSlideDraft {
  const factory AiSlideDraft({
    required String title,
    required String layout,
    required List<String> lines,
    SlideDesignStyle? designStyle,
    @Default('') String designHeaderLabel,
    @Default('') String designSubtitle,
    int? designBackgroundColor,
    int? designTextColor,
    int? designAccentColor,
    @Default('auto') String designLayout,
    @Default(900) int designFontWeight,
    @Default(true) bool designItalic,
    @Default(1.0) double designSpacing,
    @Default(true) bool showTimer,
    @Default(0.84) double timerX,
    @Default(0.5) double timerY,
    @Default(1.0) double timerSize,
    int? workSeconds,
    int? restSeconds,
    int? sets,
  }) = _AiSlideDraft;
}

@freezed
abstract class AiSlidesResult with _$AiSlidesResult {
  const factory AiSlidesResult({
    required List<AiSlideDraft> slides,
    required List<String> warnings,
    required int remaining,
    @Default(false) bool cached,
  }) = _AiSlidesResult;
}

class AiSlidesFailure implements Exception {
  const AiSlidesFailure(this.message, {this.code, this.reason});
  final String message;
  final String? code, reason;
  @override
  String toString() => message;
}
