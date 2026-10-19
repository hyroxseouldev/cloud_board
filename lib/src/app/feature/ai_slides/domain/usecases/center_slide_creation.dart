import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

String? centerSlideDraftError(AiSlideDraft draft) {
  final recipe = draft.centerRecipe;
  if (recipe == null) return '센터 템플릿을 다시 선택해 주세요.';
  final recipeError = validateCenterSlideRecipe(recipe);
  if (recipeError != null) return '템플릿 정보를 확인할 수 없어요. 다시 선택해 주세요.';
  final flow = recipe.body != null;
  if (flow) {
    final contentError = centerSlideFlowContentError(draft.lines);
    if (contentError != null) return contentError;
  }
  if (!flow &&
      draft.lines.any((line) => line.contains('\n') || line.contains('\r'))) {
    return '영역별로 넣을 수 있는 줄 수를 초과했어요. 입력한 내용을 줄여 주세요.';
  }
  if (draft.title.trim().isEmpty || draft.title.length > 60) {
    return '슬라이드 제목은 1~60자로 입력해 주세요.';
  }
  if (draft.designSubtitle.length > 120 ||
      draft.designHeaderLabel.length > 120 ||
      (!flow && draft.lines.any((line) => line.length > 120))) {
    return '각 문구는 120자 이내로 입력해 주세요.';
  }
  final indexes = recipe.fields
      .where((field) => field.binding == 'line')
      .map((field) => field.lineIndex!)
      .toSet();
  for (var i = 0; i < draft.lines.length; i++) {
    if (!flow && !indexes.contains(i) && draft.lines[i].trim().isNotEmpty) {
      return '이 템플릿의 운동 문구는 ${indexes.length}개 영역에 넣을 수 있어요.';
    }
  }
  final defaults = WorkoutModule.empty('center-validation');
  final work = draft.workSeconds ?? defaults.workSeconds;
  final rest = draft.restSeconds ?? defaults.restSeconds;
  final sets = draft.sets ?? defaults.sets;
  if (work < 1 ||
      work > 3600 ||
      rest < 0 ||
      rest > 3600 ||
      sets < 1 ||
      sets > 100) {
    return '타이머 정보를 확인해 주세요.';
  }
  return null;
}

/// A center recipe ends at creation. Playback receives the same image module
/// contract as an uploaded PNG, without a new renderer or catalog dependency.
WorkoutModule confirmCenterSlide(AiSlideDraft draft, String id, Uint8List png) {
  final error = centerSlideDraftError(draft);
  if (error != null) throw AiSlidesFailure(error);
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (png.length < signature.length ||
      signature.indexed.any((entry) => png[entry.$1] != entry.$2)) {
    throw const AiSlidesFailure('슬라이드 이미지를 만들지 못했어요. 다시 시도해 주세요.');
  }
  return previewAiSlide(draft, id).copyWith(
    imageSource: 'data:image/png;base64,${base64Encode(png)}',
    designTemplate: null,
    designStyle: null,
    designFingerprint: null,
  );
}
