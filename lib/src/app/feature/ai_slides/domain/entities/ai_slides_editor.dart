import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

part 'ai_slides_editor.freezed.dart';

/// Reusable visual preferences only; lesson content and timings stay in drafts.
@freezed
abstract class AiSlideTheme with _$AiSlideTheme {
  const factory AiSlideTheme({
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
  }) = _AiSlideTheme;
}

@freezed
abstract class AiSlidesSavedDraft with _$AiSlidesSavedDraft {
  const factory AiSlidesSavedDraft({
    @Default('') String prompt,
    String? generatedPrompt,
    AiSlideDraft? draft,
    @Default([]) List<String> warnings,
  }) = _AiSlidesSavedDraft;
}

@freezed
abstract class AiSlidesEditorState with _$AiSlidesEditorState {
  const factory AiSlidesEditorState({
    @Default('') String prompt,
    String? generatedPrompt,
    AiSlideDraft? draft,
    @Default([]) List<String> warnings,
    @Default(false) bool generating,
    @Default(true) bool loading,
    String? error,
    String? storageError,
    @Default(false) bool canUndo,
    AiSlideTheme? theme,
    @Default(false) bool themeSaving,
    @Default(false) bool themeSaved,
    String? themeError,
    int? remaining,
    @Default(false) bool cached,
  }) = _AiSlidesEditorState;
}

AiSlideTheme aiSlideThemeFromDraft(AiSlideDraft draft) => AiSlideTheme(
  designBackgroundColor: draft.designBackgroundColor,
  designTextColor: draft.designTextColor,
  designAccentColor: draft.designAccentColor,
  designLayout: draft.designLayout,
  designFontWeight: draft.designFontWeight,
  designItalic: draft.designItalic,
  designSpacing: draft.designSpacing,
  showTimer: draft.showTimer,
  timerX: draft.timerX,
  timerY: draft.timerY,
  timerSize: draft.timerSize,
);

AiSlideDraft applyAiSlideTheme(AiSlideDraft draft, AiSlideTheme theme) =>
    draft.copyWith(
      designBackgroundColor: theme.designBackgroundColor,
      designTextColor: theme.designTextColor,
      designAccentColor: theme.designAccentColor,
      designLayout: theme.designLayout,
      designFontWeight: theme.designFontWeight,
      designItalic: theme.designItalic,
      designSpacing: theme.designSpacing,
      showTimer: theme.showTimer,
      timerX: theme.timerX,
      timerY: theme.timerY,
      timerSize: theme.timerSize,
    );
