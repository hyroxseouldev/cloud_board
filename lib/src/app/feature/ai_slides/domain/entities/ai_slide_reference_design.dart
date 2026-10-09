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

// The registered template's baseline is supplied by original_slide_template.
// Keep this helper in the feature layer so the renderer never depends on drafts.
AiSlideDraft initialAiSlideDesignDraft(AiSlideTheme theme) =>
    theme.designStyle?.originalTemplate == dolpaBrickOriginalTemplateId
    ? const AiSlideDraft(
        title: dolpaBrickOriginalTitle,
        layout: 'list',
        designSubtitle: dolpaBrickOriginalSubtitle,
        lines: dolpaBrickOriginalLines,
        showTimer: false,
      )
    : aiSlideDesignSample;
