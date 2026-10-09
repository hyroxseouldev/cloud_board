import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

const slideDesignMaxLines = 24;
const slideDesignMaxLineLength = 120;
const slideDesignMaxTextLength =
    slideDesignMaxLines * (slideDesignMaxLineLength + 1) - 1;

const slideDesigns = <String, String>{
  'stationd-v2-numbered': '웜업 · 번호 목록',
  'stationd-v2-list': '운동 목록',
  'stationd-v2-interval': '인터벌',
};

const studioSlideDesigns = <String, String>{
  'studio-v1-numbered': '번호 목록',
  'studio-v1-list': '운동 목록',
  'studio-v1-interval': '인터벌',
};

const slideDesignFamilies = <String, String>{
  'banner': '밝은 번호 보드',
  'focus': '어두운 집중 보드',
  'editorial': '클래스 포스터',
  'cards': '섹션 카드 보드',
};

const slideDesignFontFamilies = <String, String>{'sans': '고딕', 'serif': '명조'};

bool isStudioSlideDesign(WorkoutModule module) =>
    studioSlideDesigns.containsKey(module.designTemplate);

bool _supportsStudioStyle(WorkoutModule module) {
  final style = module.designStyle;
  return style == null ||
      (style.version == 1 &&
          slideDesignFamilies.containsKey(style.family) &&
          slideDesignFontFamilies.containsKey(style.fontFamily) &&
          (style.originalTemplate == null ||
              style.originalTemplate == dolpaBrickOriginalTemplateId));
}

const legacySlideDesigns = <String, String>{
  'stationd-v1-numbered': '웜업 · 번호 목록',
  'stationd-v1-list': '운동 목록',
  'stationd-v1-interval': '인터벌',
};

const slideDesignLayouts = <String, String>{
  'auto': '큰 글씨',
  'columns': '2열',
  'cards': '섹션 카드',
};

typedef SlideDesignSection = ({String heading, List<String> lines});

/// Headings are stored in the editable text, so editing or copying a slide
/// cannot leave a second, stale section structure behind.
List<SlideDesignSection> parseSlideDesignSections(String text) {
  final sections = <SlideDesignSection>[];
  var heading = '';
  var lines = <String>[];
  var explicit = false;
  void flush() {
    if (explicit || heading.isNotEmpty || lines.isNotEmpty) {
      sections.add((heading: heading, lines: List.unmodifiable(lines)));
    }
  }

  for (final line in slideDesignLines(text)) {
    if (line == '##' || line.startsWith('## ')) {
      flush();
      heading = line.length > 2 ? line.substring(3).trim() : '';
      lines = [];
      explicit = true;
    } else {
      lines.add(line);
    }
  }
  flush();
  return List.unmodifiable(sections);
}

String serializeSlideDesignSections(Iterable<SlideDesignSection> sections) {
  final values = sections.toList();
  return values
      .expand(
        (section) => [
          if (section.heading.trim().isNotEmpty)
            '## ${section.heading.trim()}'
          else if (values.length > 1 || section.lines.isEmpty)
            '##',
          ...section.lines
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty),
        ],
      )
      .join('\n');
}

/// v2 exports include section and typography layout baked into the PNG. Older
/// apps intentionally do not recognize this version, so they show that image
/// instead of running their v1 renderer over section markers.
String? slideDesignKind(WorkoutModule module) {
  final template = module.designTemplate;
  // A newer saved style keeps its baked PNG until this client understands its
  // contract, rather than silently painting a different layout or typeface.
  if (isStudioSlideDesign(module) && !_supportsStudioStyle(module)) return null;
  if (!slideDesigns.containsKey(template) &&
      !legacySlideDesigns.containsKey(template) &&
      !studioSlideDesigns.containsKey(template)) {
    return null;
  }
  return template!.split('-').last;
}

bool hasSlideDesign(WorkoutModule module) => slideDesignKind(module) != null;

/// Keep an existing v1 selection valid without duplicate labels in the editor.
Map<String, String> slideDesignOptions(WorkoutModule module) =>
    isStudioSlideDesign(module)
    ? studioSlideDesigns
    : legacySlideDesigns.containsKey(module.designTemplate)
    ? legacySlideDesigns
    : slideDesigns;

List<String> slideDesignLines(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

String? slideDesignError(WorkoutModule module) {
  if (isStudioSlideDesign(module) && !_supportsStudioStyle(module)) {
    return '이 슬라이드 디자인을 편집하려면 앱을 업데이트해 주세요.';
  }
  if (!hasSlideDesign(module)) return null;
  if (isOriginalSlideTemplate(module)) {
    return originalSlideValidationError(module);
  }
  if (module.name.trim().isEmpty || module.name.length > 60) {
    return '테마 슬라이드 제목은 1~60자로 입력해 주세요.';
  }
  if (!slideDesignLayouts.containsKey(module.designLayout) ||
      ![400, 500, 600, 700, 800, 900].contains(module.designFontWeight) ||
      !module.designSpacing.isFinite ||
      module.designSpacing < 0.8 ||
      module.designSpacing > 1.5) {
    return '슬라이드 디자인 설정을 다시 확인해 주세요.';
  }
  if (isStudioSlideDesign(module)) {
    final style = module.designStyle;
    if ((style != null &&
            (style.version != 1 ||
                !slideDesignFamilies.containsKey(style.family) ||
                !slideDesignFontFamilies.containsKey(style.fontFamily) ||
                ![400, 500, 600, 700, 800, 900].contains(style.titleWeight) ||
                style.motif.length > 40)) ||
        module.designHeaderLabel.length > 120 ||
        module.designSubtitle.length > 120) {
      return '슬라이드 디자인 설정을 다시 확인해 주세요.';
    }
  }
  final lines = parseSlideDesignSections(module.text)
      .expand(
        (section) => [
          if (section.heading.isNotEmpty) section.heading,
          ...section.lines,
        ],
      )
      .toList();
  if (lines.length > slideDesignMaxLines ||
      lines.any((line) => line.length > slideDesignMaxLineLength)) {
    return '테마 슬라이드는 최대 24줄, 한 줄에 120자까지 입력할 수 있어요.';
  }
  return null;
}
