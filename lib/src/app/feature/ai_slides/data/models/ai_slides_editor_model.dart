import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';

part 'ai_slides_editor_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AiSlidesSavedDraftModel {
  const AiSlidesSavedDraftModel({
    this.schemaVersion = 1,
    required this.prompt,
    this.generatedPrompt,
    this.draft,
    this.warnings = const [],
  });
  final int schemaVersion;
  final String prompt;
  final String? generatedPrompt;
  final AiSlideDraftModel? draft;
  final List<String> warnings;
  factory AiSlidesSavedDraftModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlidesSavedDraftModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlidesSavedDraftModelToJson(this);
  factory AiSlidesSavedDraftModel.fromEntity(AiSlidesSavedDraft value) =>
      AiSlidesSavedDraftModel(
        prompt: value.prompt,
        generatedPrompt: value.generatedPrompt,
        draft: value.draft == null
            ? null
            : AiSlideDraftModel.fromEntity(value.draft!),
        warnings: value.warnings,
      );
  AiSlidesSavedDraft toEntity() {
    if (schemaVersion != 1 || prompt.length > 6000) {
      throw const FormatException('Unsupported AI slide draft');
    }
    return AiSlidesSavedDraft(
      prompt: prompt,
      generatedPrompt: generatedPrompt,
      draft: draft?.toEntity(),
      warnings: warnings,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class AiSlideDraftModel {
  const AiSlideDraftModel({
    required this.title,
    required this.layout,
    required this.lines,
    this.designHeaderLabel = '',
    this.designSubtitle = '',
    this.designStyle,
    this.designBackgroundColor,
    this.designTextColor,
    this.designAccentColor,
    this.workSeconds,
    this.restSeconds,
    this.sets,
    this.designLayout = 'auto',
    this.designFontWeight = 900,
    this.designItalic = true,
    this.designSpacing = 1.0,
    this.showTimer = true,
    this.timerX = 0.84,
    this.timerY = 0.5,
    this.timerSize = 1.0,
  });
  final String title, layout, designHeaderLabel, designSubtitle;
  final List<String> lines;
  final SlideDesignStyle? designStyle;
  final int? designBackgroundColor, designTextColor, designAccentColor;
  final int? workSeconds, restSeconds, sets;
  final String designLayout;
  final int designFontWeight;
  final bool designItalic, showTimer;
  final double designSpacing, timerX, timerY, timerSize;
  factory AiSlideDraftModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlideDraftModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlideDraftModelToJson(this);
  factory AiSlideDraftModel.fromEntity(AiSlideDraft draft) => AiSlideDraftModel(
    title: draft.title,
    layout: draft.layout,
    lines: draft.lines,
    designStyle: draft.designStyle,
    designHeaderLabel: draft.designHeaderLabel,
    designSubtitle: draft.designSubtitle,
    designBackgroundColor: draft.designBackgroundColor,
    designTextColor: draft.designTextColor,
    designAccentColor: draft.designAccentColor,
    workSeconds: draft.workSeconds,
    restSeconds: draft.restSeconds,
    sets: draft.sets,
    designLayout: draft.designLayout,
    designFontWeight: draft.designFontWeight,
    designItalic: draft.designItalic,
    designSpacing: draft.designSpacing,
    showTimer: draft.showTimer,
    timerX: draft.timerX,
    timerY: draft.timerY,
    timerSize: draft.timerSize,
  );
  AiSlideDraft toEntity() {
    _validateVisuals(toJson());
    _validateStudioStyle(designStyle);
    return AiSlideDraft(
      title: title,
      layout: layout,
      lines: lines,
      designHeaderLabel: designHeaderLabel,
      designSubtitle: designSubtitle,
      designStyle: designStyle,
      designBackgroundColor: designBackgroundColor,
      designTextColor: designTextColor,
      designAccentColor: designAccentColor,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      sets: sets,
      designLayout: designLayout,
      designFontWeight: designFontWeight,
      designItalic: designItalic,
      designSpacing: designSpacing,
      showTimer: showTimer,
      timerX: timerX,
      timerY: timerY,
      timerSize: timerSize,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class AiSlideThemeModel {
  const AiSlideThemeModel({
    this.schemaVersion = 1,
    this.designStyle,
    this.designBackgroundColor,
    this.designTextColor,
    this.designAccentColor,
    this.designLayout = 'auto',
    this.designFontWeight = 900,
    this.designItalic = true,
    this.designSpacing = 1.0,
    this.showTimer = true,
    this.timerX = 0.84,
    this.timerY = 0.5,
    this.timerSize = 1.0,
  });
  final int schemaVersion;
  final SlideDesignStyle? designStyle;
  final int? designBackgroundColor, designTextColor, designAccentColor;
  final String designLayout;
  final int designFontWeight;
  final bool designItalic, showTimer;
  final double designSpacing, timerX, timerY, timerSize;
  factory AiSlideThemeModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlideThemeModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlideThemeModelToJson(this);
  factory AiSlideThemeModel.fromEntity(AiSlideTheme theme) => AiSlideThemeModel(
    designStyle: theme.designStyle,
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
  AiSlideTheme toEntity() {
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported AI slide theme');
    }
    _validateVisuals(toJson());
    _validateStudioStyle(designStyle);
    return AiSlideTheme(
      designStyle: designStyle,
      designBackgroundColor: designBackgroundColor,
      designTextColor: designTextColor,
      designAccentColor: designAccentColor,
      designLayout: designLayout,
      designFontWeight: designFontWeight,
      designItalic: designItalic,
      designSpacing: designSpacing,
      showTimer: showTimer,
      timerX: timerX,
      timerY: timerY,
      timerSize: timerSize,
    );
  }
}

void _validateVisuals(Map<String, dynamic> json) {
  bool numberWithin(String key, double min, double max) {
    final value = json[key];
    return value is num && value.isFinite && value >= min && value <= max;
  }

  for (final key in [
    'designBackgroundColor',
    'designTextColor',
    'designAccentColor',
  ]) {
    final value = json[key];
    if (value != null && (value is! int || value < 0 || value > 0xFFFFFFFF)) {
      throw const FormatException('Invalid slide color');
    }
  }
  if (!['auto', 'columns', 'cards'].contains(json['designLayout']) ||
      ![400, 500, 600, 700, 800, 900].contains(json['designFontWeight']) ||
      !numberWithin('designSpacing', 0.8, 1.5) ||
      !numberWithin('timerX', 0, 1) ||
      !numberWithin('timerY', 0, 1) ||
      !numberWithin('timerSize', 0.5, 1.8)) {
    throw const FormatException('Invalid slide style');
  }
}

void _validateStudioStyle(SlideDesignStyle? style) {
  if (style == null) return;
  if (style.version != 1 ||
      !['banner', 'focus', 'editorial', 'cards'].contains(style.family) ||
      !['sans', 'serif'].contains(style.fontFamily) ||
      ![400, 500, 600, 700, 800, 900].contains(style.titleWeight) ||
      style.motif.length > 12 ||
      (style.originalTemplate != null &&
          style.originalTemplate != dolpaBrickOriginalTemplateId) ||
      (style.titleColor != null &&
          (style.titleColor! < 0xFF000000 || style.titleColor! > 0xFFFFFFFF))) {
    throw const FormatException('Invalid studio style');
  }
}
