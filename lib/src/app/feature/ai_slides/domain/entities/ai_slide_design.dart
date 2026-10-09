import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';

part 'ai_slide_design.freezed.dart';

@freezed
abstract class AiSlideDesign with _$AiSlideDesign {
  const factory AiSlideDesign({
    required String id,
    required String name,
    @Default('') String description,
    required AiSlideTheme theme,
    String? storeId,
  }) = _AiSlideDesign;
}

@freezed
abstract class AiSlideDesignResult with _$AiSlideDesignResult {
  const factory AiSlideDesignResult({
    required List<AiSlideDesign> designs,
    @Default([]) List<String> warnings,
    required int remaining,
    @Default(false) bool cached,
  }) = _AiSlideDesignResult;
}

@freezed
abstract class AiSlideDesignStudioState with _$AiSlideDesignStudioState {
  const factory AiSlideDesignStudioState({
    @Default([]) List<AiSlideDesign> proposals,
    @Default([]) List<AiSlideDesign> templates,
    AiSlideDesign? selected,
    @Default(false) bool generating,
    @Default(false) bool saving,
    @Default(false) bool templatesLoading,
    @Default(false) bool saved,
    @Default([]) List<String> warnings,
    String? error,
    String? templateError,
    int? remaining,
  }) = _AiSlideDesignStudioState;
}

/// These styles contain no customer's names, artwork, or lesson content.
const aiSlideDesignCatalog = <AiSlideDesign>[
  AiSlideDesign(
    id: 'catalog-banner',
    name: '밝은 번호 보드',
    description: '선명한 헤더와 번호로 운동 순서를 한눈에',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(family: 'banner', titleColor: 0xff18251f),
      designBackgroundColor: 0xfff5f6ed,
      designTextColor: 0xff18251f,
      designAccentColor: 0xffbfe56b,
      designItalic: false,
      designFontWeight: 700,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-focus',
    name: '어두운 집중 보드',
    description: '짙은 배경과 큰 운동행으로 집중도를 높여요',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(family: 'focus', titleColor: 0xfff6f7f2),
      designBackgroundColor: 0xff141d1a,
      designTextColor: 0xfff6f7f2,
      designAccentColor: 0xffc3f06b,
      designItalic: false,
      designFontWeight: 800,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-editorial',
    name: '클래스 포스터',
    description: '큰 제목과 세리프 글씨로 클래스의 분위기를',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'editorial',
        fontFamily: 'serif',
        titleColor: 0xfff1ebe1,
        titleWeight: 800,
        motif: 'CLASS',
      ),
      designBackgroundColor: 0xff211c21,
      designTextColor: 0xfff1ebe1,
      designAccentColor: 0xffe9654b,
      designItalic: false,
      designFontWeight: 600,
      designSpacing: 1.1,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-cards',
    name: '섹션 카드 보드',
    description: '웜업부터 메인까지 여러 파트를 또렷하게',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(family: 'cards', titleColor: 0xff172741),
      designBackgroundColor: 0xffeef2f8,
      designTextColor: 0xff172741,
      designAccentColor: 0xff4969dd,
      designItalic: false,
      designFontWeight: 700,
      designSpacing: 1.0,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-minimal-white',
    name: '미니멀 화이트',
    description: '담백한 흰 배경과 여유 있는 목록으로 또렷하게',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'focus',
        titleColor: 0xff252725,
        titleWeight: 700,
      ),
      designBackgroundColor: 0xfffbfbf8,
      designTextColor: 0xff252725,
      designAccentColor: 0xff3c493f,
      designItalic: false,
      designFontWeight: 600,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-orange-speed',
    name: '오렌지 스피드',
    description: '오렌지 헤더와 역동적인 2열 운동 목록',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(family: 'banner', titleColor: 0xff281b11),
      designBackgroundColor: 0xfffff3e4,
      designTextColor: 0xff2d211b,
      designAccentColor: 0xfff5963f,
      designLayout: 'columns',
      designItalic: true,
      designFontWeight: 800,
      designSpacing: 0.98,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-blue-night',
    name: '블루 나이트',
    description: '깊은 네이비와 시원한 블루 포인트의 2열 보드',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'focus',
        titleColor: 0xffecf4ff,
        titleWeight: 800,
      ),
      designBackgroundColor: 0xff101f36,
      designTextColor: 0xffecf4ff,
      designAccentColor: 0xff79d6f2,
      designLayout: 'columns',
      designItalic: false,
      designFontWeight: 700,
      designSpacing: 1.05,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-coral-circuit',
    name: '코랄 서킷',
    description: '따뜻한 코랄 카드로 스테이션마다 구분해요',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'cards',
        titleColor: 0xff7f3830,
        titleWeight: 800,
      ),
      designBackgroundColor: 0xfffff1ec,
      designTextColor: 0xff4b2928,
      designAccentColor: 0xffba493b,
      designItalic: false,
      designFontWeight: 600,
      designSpacing: 1.02,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-neon-stations',
    name: '네온 스테이션',
    description: '네온 헤더와 어두운 운동 카드로 강렬하게',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(family: 'banner', titleColor: 0xff1a2413),
      designBackgroundColor: 0xff172019,
      designTextColor: 0xfffafcea,
      designAccentColor: 0xffd6f657,
      designLayout: 'cards',
      designItalic: false,
      designFontWeight: 800,
      designSpacing: 0.96,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-lavender-flow',
    name: '라벤더 플로우',
    description: '부드러운 라벤더 카드와 차분한 글씨의 조화',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'focus',
        titleColor: 0xff4b366d,
        titleWeight: 700,
      ),
      designBackgroundColor: 0xfff3eef9,
      designTextColor: 0xff45365b,
      designAccentColor: 0xff7961aa,
      designLayout: 'cards',
      designItalic: false,
      designFontWeight: 600,
      designSpacing: 1.04,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-cream-classic',
    name: '크림 클래식',
    description: '크림색 바탕과 명조 글씨로 편안한 클래스',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'editorial',
        fontFamily: 'serif',
        titleColor: 0xff342a24,
        titleWeight: 700,
        motif: 'MOVE',
      ),
      designBackgroundColor: 0xfff5efe1,
      designTextColor: 0xff45382f,
      designAccentColor: 0xffa37e4a,
      designItalic: false,
      designFontWeight: 500,
      designSpacing: 1.08,
      showTimer: false,
    ),
  ),
  AiSlideDesign(
    id: 'catalog-red-impact',
    name: '레드 임팩트',
    description: '레드 배경과 굵은 글씨로 에너지 넘치는 포스터',
    theme: AiSlideTheme(
      designStyle: SlideDesignStyle(
        family: 'editorial',
        titleColor: 0xfffff4e3,
        titleWeight: 900,
        motif: 'POWER',
      ),
      designBackgroundColor: 0xffa72532,
      designTextColor: 0xfffff4e3,
      designAccentColor: 0xffffc7a8,
      designItalic: true,
      designFontWeight: 800,
      showTimer: false,
    ),
  ),
];

/// All design alternatives use exactly the same editable lesson preview.
const aiSlideDesignSample = AiSlideDraft(
  title: '오늘의 클래스',
  layout: 'numbered',
  designHeaderLabel: 'DAILY TRAINING',
  designSubtitle: '6 min ON / 90 sec OFF',
  lines: [
    'Ski 250m + Run 250m',
    'Goblet Squat 12',
    'DB Press 10',
    'Wall Ball 20',
  ],
  showTimer: false,
);
