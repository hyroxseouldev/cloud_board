import 'dart:ui';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

/// Customer-provided artwork, deliberately separate from the default catalog.
const dolpaBrickOriginalTemplateId = 'dolpa-brick-v1';
const dolpaBrickOriginalAsset =
    'assets/slide_templates/dolpa_brick_original.png';
const dolpaBrickOriginalTitle = 'Brick Session';
const dolpaBrickOriginalSubtitle = '6mins On / 90s Off';
const dolpaBrickOriginalLines = [
  'Ski 250m + Sled Pull 1 Way',
  'Run 250m + FMCTP 30',
  'Ski 250m + Wall Ball 30',
  'DV Press 8 + BTP 10',
];

const originalSlideSourceSize = Size(2316, 1262);
const originalSlideOutputSize = Size(1920, 1080);

/// Bounds are measured in unmodified source pixels. They leave the calligraphy
/// clear. The title overlaps the top-left calligraphy in the flattened source,
/// so it remains fixed and is never erased or repainted.
const originalSlideTitleBounds = Rect.fromLTRB(180, 250, 1120, 390);
const originalSlideSubtitleBounds = Rect.fromLTRB(198, 476, 1070, 584);
const originalSlideExerciseBounds = [
  Rect.fromLTRB(198, 636, 1070, 727),
  Rect.fromLTRB(198, 772, 1070, 863),
  Rect.fromLTRB(198, 908, 1070, 999),
  Rect.fromLTRB(198, 1044, 1070, 1135),
];

bool isOriginalSlideTemplate(WorkoutModule module) =>
    module.designStyle?.originalTemplate == dolpaBrickOriginalTemplateId;

List<String> originalSlideLines(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

String? originalSlideValidationError(WorkoutModule module) {
  final id = module.designStyle?.originalTemplate;
  if (id == null) return null;
  if (id != dolpaBrickOriginalTemplateId) {
    return '이 원본 템플릿을 편집하려면 앱을 업데이트해 주세요.';
  }
  if (module.showTimer || module.showSets) {
    return '원본 그림을 보존하려면 타이머와 세트 표시를 꺼 주세요.';
  }
  if (module.name.trim() != dolpaBrickOriginalTitle) {
    return '이 원본 템플릿의 제목은 Brick Session으로 고정되어 있어요. 시간과 운동 문구를 수정해 주세요.';
  }
  final lines = originalSlideLines(module.text);
  if (lines.length > 4) return '이 원본 템플릿에는 운동을 최대 4줄까지 넣을 수 있어요.';
  if (lines.any((line) => line == '##' || line.startsWith('## '))) {
    return '이 원본 템플릿은 섹션 제목 없이 운동 4줄을 사용해요.';
  }
  if (module.designSubtitle.length > 120 ||
      lines.any((line) => line.length > 120)) {
    return '원본 템플릿의 시간과 운동은 한 줄에 120자까지 입력해 주세요.';
  }
  return null;
}

/// The source aspect ratio is preserved; unused output space stays black.
Rect originalSlideImageRect(Size size) {
  final scale = (size.width / originalSlideSourceSize.width).clamp(
    0.0,
    size.height / originalSlideSourceSize.height,
  );
  final width = originalSlideSourceSize.width * scale;
  final height = originalSlideSourceSize.height * scale;
  return Rect.fromLTWH(
    (size.width - width) / 2,
    (size.height - height) / 2,
    width,
    height,
  );
}
