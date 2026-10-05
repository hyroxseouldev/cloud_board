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
    int? designBackgroundColor,
    int? designTextColor,
    int? designAccentColor,
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
  const AiSlidesFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
