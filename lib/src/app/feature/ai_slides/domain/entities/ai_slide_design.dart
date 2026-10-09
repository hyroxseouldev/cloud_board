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
