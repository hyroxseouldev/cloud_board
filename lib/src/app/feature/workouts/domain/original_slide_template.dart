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

/// Measured editable regions of a registered, unmodified customer image.
class OriginalSlideTemplate {
  const OriginalSlideTemplate({
    required this.id,
    required this.asset,
    required this.sourceSize,
    required this.title,
    required this.subtitle,
    required this.lines,
    required this.titleBounds,
    required this.subtitleBounds,
    required this.exerciseBounds,
    required this.accentColor,
    this.programLabel = '',
    this.numberBounds = const [],
    this.backgroundColor = 0xFFFFFFFF,
    this.textColor = 0xFF000000,
    this.fontFamily = 'Pretendard',
    this.fixedTitle = false,
    this.titleFontSize = 184,
    this.subtitleFontSize = 146,
    this.bodyFontSize = 106,
    this.bodyWeight = 700,
  });
  final String id, asset, title, subtitle, programLabel, fontFamily;
  final Size sourceSize;
  final List<String> lines;
  final Rect titleBounds, subtitleBounds;
  final List<Rect> exerciseBounds, numberBounds;
  final int backgroundColor, textColor, accentColor, bodyWeight;
  final double titleFontSize, subtitleFontSize, bodyFontSize;
  final bool fixedTitle;
  int get maxLines => exerciseBounds.length;
}

const dolpaOriginalTemplate = OriginalSlideTemplate(
  id: dolpaBrickOriginalTemplateId,
  asset: dolpaBrickOriginalAsset,
  sourceSize: originalSlideSourceSize,
  title: dolpaBrickOriginalTitle,
  subtitle: dolpaBrickOriginalSubtitle,
  lines: dolpaBrickOriginalLines,
  titleBounds: originalSlideTitleBounds,
  subtitleBounds: originalSlideSubtitleBounds,
  exerciseBounds: originalSlideExerciseBounds,
  accentColor: 0xFFEA3458,
  backgroundColor: 0xFF000000,
  textColor: 0xFFFFFFFF,
  fontFamily: 'NotoSerifKR',
  fixedTitle: true,
  titleFontSize: 110,
  subtitleFontSize: 65,
  bodyFontSize: 60,
  bodyWeight: 400,
);

OriginalSlideTemplate? originalSlideTemplate(String? id) =>
    originalSlideTemplates.where((template) => template.id == id).firstOrNull;

bool isOriginalSlideTemplate(WorkoutModule module) =>
    originalSlideTemplate(module.designStyle?.originalTemplate) != null;

List<String> originalSlideLines(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

String? originalSlideValidationError(WorkoutModule module) {
  final id = module.designStyle?.originalTemplate;
  if (id == null) return null;
  final template = originalSlideTemplate(id);
  if (template == null) {
    return '이 원본 템플릿을 편집하려면 앱을 업데이트해 주세요.';
  }
  if (module.name.trim().isEmpty || module.name.length > 60) {
    return '슬라이드 제목은 1~60자로 입력해 주세요.';
  }
  final lines = originalSlideLines(module.text);
  if (lines.length > template.maxLines) {
    return '이 원본 템플릿에는 운동을 최대 ${template.maxLines}줄까지 넣을 수 있어요.';
  }
  if (lines.any((line) => line == '##' || line.startsWith('## '))) {
    return '이 원본 템플릿은 섹션 제목 없이 운동 ${template.maxLines}줄을 사용해요.';
  }
  if (module.designSubtitle.length > 120 ||
      lines.any((line) => line.length > 120)) {
    return '원본 템플릿의 시간과 운동은 한 줄에 120자까지 입력해 주세요.';
  }
  return null;
}

/// The source aspect ratio is preserved; unused output space stays black.
Rect originalSlideImageRect(
  Size size, {
  Size sourceSize = originalSlideSourceSize,
}) {
  final scale = (size.width / sourceSize.width).clamp(
    0.0,
    size.height / sourceSize.height,
  );
  final width = sourceSize.width * scale;
  final height = sourceSize.height * scale;
  return Rect.fromLTWH(
    (size.width - width) / 2,
    (size.height - height) / 2,
    width,
    height,
  );
}

const stationDOriginalTemplates = <OriginalSlideTemplate>[
  OriginalSlideTemplate(
    id: 'stationd-mon-v1',
    asset: 'assets/slide_templates/stationd_mon_original.png',
    sourceSize: Size(3840, 2160),
    title: "SINGLE : AMRAP",
    programLabel: "UNBROKEN",
    subtitle: "5mins On / 90s Off",
    accentColor: 0xFFFF6200,
    titleBounds: Rect.fromLTRB(270, 70, 2510, 292),
    subtitleBounds: Rect.fromLTRB(269, 514, 3630, 657),
    lines: [
      "Run B 1000 / S 1150 / C 1350+",
      "Ski B 1000 / S 1100 / C 1300+",
      "Sled Pull B 5 / S 6 / C 7",
      "Row B 1000 / S 1150 / C 1300+",
      "FMCTP 20 + BTP 10 B 4 / S 5 / C 6",
      "Wall Ball B 90 / S 105 / C 120",
    ],
    exerciseBounds: [
      Rect.fromLTRB(564, 778, 3680, 890),
      Rect.fromLTRB(564, 988, 3680, 1100),
      Rect.fromLTRB(564, 1197, 3680, 1310),
      Rect.fromLTRB(564, 1407, 3680, 1519),
      Rect.fromLTRB(564, 1617, 3680, 1729),
      Rect.fromLTRB(564, 1826, 3680, 1938),
    ],
    numberBounds: [
      Rect.fromLTRB(269, 757, 423, 900),
      Rect.fromLTRB(269, 967, 423, 1110),
      Rect.fromLTRB(269, 1177, 423, 1320),
      Rect.fromLTRB(269, 1386, 423, 1529),
      Rect.fromLTRB(269, 1596, 423, 1739),
      Rect.fromLTRB(269, 1805, 423, 1948),
    ],
  ),
  OriginalSlideTemplate(
    id: 'stationd-tue-v1',
    asset: 'assets/slide_templates/stationd_tue_original.png',
    sourceSize: Size(3840, 2160),
    title: "TEAM OF 2 : IGYG",
    programLabel: "STRENGTH",
    subtitle: "6mins On / 1min Off",
    accentColor: 0xFF003E77,
    titleBounds: Rect.fromLTRB(270, 70, 2510, 292),
    subtitleBounds: Rect.fromLTRB(345, 505, 3630, 648),
    lines: [
      "Heavy Sled Push 1 Way",
      "OHP 8",
      "Heavy Sled Pull Half Way",
      "Gorilla Row 20",
      "DB Heavy Back Lunge 16",
      "Incline DB Press 12",
    ],
    exerciseBounds: [
      Rect.fromLTRB(640, 739, 3680, 857),
      Rect.fromLTRB(640, 962, 3680, 1061),
      Rect.fromLTRB(640, 1182, 3680, 1303),
      Rect.fromLTRB(640, 1394, 3680, 1496),
      Rect.fromLTRB(640, 1608, 3680, 1727),
      Rect.fromLTRB(640, 1816, 3680, 1918),
    ],
    numberBounds: [
      Rect.fromLTRB(344, 720, 498, 853),
      Rect.fromLTRB(344, 943, 498, 1076),
      Rect.fromLTRB(344, 1166, 498, 1299),
      Rect.fromLTRB(344, 1378, 498, 1511),
      Rect.fromLTRB(344, 1589, 498, 1722),
      Rect.fromLTRB(344, 1800, 498, 1933),
    ],
  ),
  OriginalSlideTemplate(
    id: 'stationd-wed-v1',
    asset: 'assets/slide_templates/stationd_wed_original.png',
    sourceSize: Size(3840, 2160),
    title: "TEAM OF 3 : RELAY",
    programLabel: "MAX",
    subtitle: "6mins On / 2mins Off",
    accentColor: 0xFF4BEE00,
    titleBounds: Rect.fromLTRB(270, 70, 2510, 292),
    subtitleBounds: Rect.fromLTRB(298, 601, 3630, 744),
    lines: [
      "Run 100m B 1500 / S 1700 / C 1900",
      "BBJ 1 Way B 150(12) / S 175(14) / C 200(16)",
      "Sled Pull 1 Way B 150(12) / S 175(14) / C 200(16)",
      "Ski 100m B 1400 / S 1600 / C 1800",
      "Bike Time Cap W 90 / M 110 / C 130",
    ],
    exerciseBounds: [
      Rect.fromLTRB(598, 826, 3680, 937),
      Rect.fromLTRB(598, 1025, 3680, 1146),
      Rect.fromLTRB(598, 1224, 3680, 1345),
      Rect.fromLTRB(598, 1423, 3680, 1534),
      Rect.fromLTRB(598, 1623, 3680, 1744),
    ],
    numberBounds: [
      Rect.fromLTRB(302, 810, 456, 943),
      Rect.fromLTRB(302, 1009, 456, 1142),
      Rect.fromLTRB(302, 1208, 456, 1341),
      Rect.fromLTRB(302, 1408, 456, 1541),
      Rect.fromLTRB(302, 1607, 456, 1740),
    ],
  ),
  OriginalSlideTemplate(
    id: 'stationd-thu-v1',
    asset: 'assets/slide_templates/stationd_thu_original.png',
    sourceSize: Size(3840, 2160),
    title: "SINGLE : E2MOM 3R",
    programLabel: "SWEAT",
    subtitle: "6mins On / 30s move",
    accentColor: 0xFF56B7F4,
    titleBounds: Rect.fromLTRB(270, 70, 2510, 292),
    subtitleBounds: Rect.fromLTRB(399, 535, 3630, 678),
    lines: [
      "Run 200m + Sled Mode 30m",
      "Ski 200m + DV Press W 5 / M 8",
      "FMC 6 Way",
      "Row 200m + SBL 30",
      "Wall Ball 30 + Hop Jump 10",
      "BTP W 10 / M 15 + Jump Squat 30",
    ],
    exerciseBounds: [
      Rect.fromLTRB(696, 771, 3680, 878),
      Rect.fromLTRB(696, 978, 3680, 1097),
      Rect.fromLTRB(696, 1189, 3680, 1317),
      Rect.fromLTRB(696, 1398, 3680, 1505),
      Rect.fromLTRB(696, 1607, 3680, 1735),
      Rect.fromLTRB(696, 1815, 3680, 1945),
    ],
    numberBounds: [
      Rect.fromLTRB(403, 757, 557, 890),
      Rect.fromLTRB(403, 966, 557, 1099),
      Rect.fromLTRB(403, 1175, 557, 1308),
      Rect.fromLTRB(403, 1385, 557, 1518),
      Rect.fromLTRB(403, 1594, 557, 1727),
      Rect.fromLTRB(403, 1803, 557, 1936),
    ],
  ),
  OriginalSlideTemplate(
    id: 'stationd-fri-v1',
    asset: 'assets/slide_templates/stationd_fri_original.png',
    sourceSize: Size(3840, 2160),
    title: "SINGLE : EMOM",
    programLabel: "HYROX",
    subtitle: "6mins On / 90s Off",
    accentColor: 0xFFCB0000,
    titleBounds: Rect.fromLTRB(270, 70, 2510, 292),
    subtitleBounds: Rect.fromLTRB(449, 541, 3630, 684),
    lines: [
      "1min Run + BTP B 12 / S 15 / C 20",
      "1min Sled Pull + Sled Pull 1 Way",
      "1min FMCTP + Ski B 150 / S 180 / C 230",
      "1min Row + SBL B 20 / S 30 / C 40",
      "1min Wall Ball + WB Squat B 20 / S 25 / C 30",
    ],
    exerciseBounds: [
      Rect.fromLTRB(741, 803, 3680, 914),
      Rect.fromLTRB(741, 1004, 3680, 1125),
      Rect.fromLTRB(741, 1204, 3680, 1315),
      Rect.fromLTRB(741, 1404, 3680, 1515),
      Rect.fromLTRB(741, 1604, 3680, 1725),
    ],
    numberBounds: [
      Rect.fromLTRB(453, 787, 607, 920),
      Rect.fromLTRB(453, 988, 607, 1121),
      Rect.fromLTRB(453, 1188, 607, 1321),
      Rect.fromLTRB(453, 1388, 607, 1521),
      Rect.fromLTRB(453, 1588, 607, 1721),
    ],
  ),
  OriginalSlideTemplate(
    id: 'stationd-sat-v1',
    asset: 'assets/slide_templates/stationd_sat_original.png',
    sourceSize: Size(3840, 2160),
    title: "TEAM OF 2",
    programLabel: "HYROX",
    subtitle: "9mins On / 2mins Off",
    accentColor: 0xFFCB0000,
    titleBounds: Rect.fromLTRB(270, 70, 2510, 292),
    subtitleBounds: Rect.fromLTRB(331, 709, 3630, 851),
    lines: [
      "Run 1000m + Ski 1000m (M+100)",
      "Sled Pull 8 Way + Row 500m",
      "SBL 150 + FMCTP 40",
      "BTP 50 + Wall Ball 150",
    ],
    exerciseBounds: [
      Rect.fromLTRB(586, 966, 3680, 1082),
      Rect.fromLTRB(586, 1168, 3680, 1286),
      Rect.fromLTRB(586, 1367, 3680, 1466),
      Rect.fromLTRB(586, 1566, 3680, 1665),
    ],
    numberBounds: [
      Rect.fromLTRB(335, 950, 489, 1083),
      Rect.fromLTRB(335, 1149, 489, 1282),
      Rect.fromLTRB(335, 1348, 489, 1481),
      Rect.fromLTRB(335, 1547, 489, 1680),
    ],
  ),
];

const originalSlideTemplates = <OriginalSlideTemplate>[
  ...stationDOriginalTemplates,
  dolpaOriginalTemplate,
];
