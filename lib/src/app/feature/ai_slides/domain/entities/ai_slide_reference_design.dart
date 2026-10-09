import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

/// A customer-owned reference is opt-in for this local verification build.
/// It must never join the shared catalog used by other centers.
const showDolpaReferenceDesign = bool.fromEnvironment(
  'CLOUDBOARD_DOLPA_REFERENCE',
);

const dolpaReferenceDesign = AiSlideDesign(
  id: 'reference-dolpa-brick',
  name: '돌파 · Brick Session 원본',
  description: '원본 배치 유지 · 운동 문구만 수정',
  theme: AiSlideTheme(
    designStyle: SlideDesignStyle(
      family: 'editorial',
      fontFamily: 'serif',
      originalTemplate: dolpaBrickOriginalTemplateId,
      titleColor: 0xffffffff,
      titleWeight: 700,
    ),
    designBackgroundColor: 0xff000000,
    designTextColor: 0xffffffff,
    designAccentColor: 0xffcf141d,
    designFontWeight: 400,
    designItalic: false,
    showTimer: false,
  ),
);

final stationDReferenceDesigns = stationDOriginalTemplates
    .map(
      (template) => AiSlideDesign(
        id: 'reference-${template.id}',
        name:
            '${template.programLabel}${template.id == 'stationd-fri-v1'
                ? ' · 싱글'
                : template.id == 'stationd-sat-v1'
                ? ' · 팀'
                : ''}',
        description: '원본 그대로 · ${template.title}',
        theme: AiSlideTheme(
          designStyle: SlideDesignStyle(
            family: 'banner',
            fontFamily: 'sans',
            originalTemplate: template.id,
            titleColor: 0xFFFFFFFF,
          ),
          designBackgroundColor: template.backgroundColor,
          designTextColor: template.textColor,
          designAccentColor: template.accentColor,
          designFontWeight: template.bodyWeight,
          designItalic: false,
          showTimer: false,
        ),
      ),
    )
    .toList(growable: false);

List<AiSlideDesign> get customerReferenceDesigns => [
  ...stationDReferenceDesigns,
  dolpaReferenceDesign,
];

AiSlideDraft initialAiSlideDesignDraft(AiSlideTheme theme) {
  final template = originalSlideTemplate(theme.designStyle?.originalTemplate);
  if (template == null) return aiSlideDesignSample;
  return AiSlideDraft(
    title: template.title,
    layout: template.numberBounds.isEmpty ? 'list' : 'numbered',
    designHeaderLabel: template.programLabel,
    designSubtitle: template.subtitle,
    lines: template.lines,
    showTimer: false,
  );
}

/// Switching sample cards loads the next original, while real lesson edits stay.
bool isUneditedAiSlideSample(AiSlideDraft draft) {
  bool sameContent(AiSlideDraft sample) =>
      draft.title == sample.title &&
      draft.designSubtitle == sample.designSubtitle &&
      draft.lines.join('\n') == sample.lines.join('\n');
  return sameContent(aiSlideDesignSample) ||
      customerReferenceDesigns.any(
        (design) => sameContent(initialAiSlideDesignDraft(design.theme)),
      );
}

/// Existing content generation returns explicit timing separately from rows.
/// Put that information back into the original image's timing slot, without
/// copying yesterday's timing or interpreting an ambiguous transition as rest.
AiSlideDraft originalSlideGeneratedContent(AiSlideDraft draft) {
  final timingLine = RegExp(
    r'^\d+(?:\.\d+)?\s*(?:mins?|minutes?|s|secs?|seconds?)\s+on\s*/\s*\d+(?:\.\d+)?\s*(?:mins?|minutes?|s|secs?|seconds?)\s+(?:off|move|rest)$',
    caseSensitive: false,
  );
  final timing = draft.lines
      .where((line) => timingLine.hasMatch(line.trim()))
      .toList();
  if (timing.length == 1) {
    return draft.copyWith(
      designSubtitle: timing.single.trim(),
      lines: draft.lines.where((line) => line != timing.single).toList(),
    );
  }
  if (draft.designSubtitle.isNotEmpty || draft.workSeconds == null) {
    return draft;
  }
  String duration(int seconds) => seconds >= 60 && seconds % 60 == 0
      ? '${seconds ~/ 60}${seconds == 60 ? 'min' : 'mins'}'
      : '${seconds}s';
  return draft.copyWith(
    designSubtitle:
        '${duration(draft.workSeconds!)} On${draft.restSeconds == null ? '' : ' / ${duration(draft.restSeconds!)} Off'}',
  );
}
