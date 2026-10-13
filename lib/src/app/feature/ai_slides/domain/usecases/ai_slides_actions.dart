import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy.dart';
import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
part 'ai_slides_actions.g.dart';

@riverpod
AiSlidesActions aiSlidesActions(Ref ref) => AiSlidesActions(
  ref.watch(aiSlidesRepositoryProvider),
  generationAllowed: (ownerId) => ref
      .read(runtimeFeaturePolicyServiceProvider)
      .allows(RuntimeFeature.aiSlideGeneration, ownerId: ownerId),
);

class AiSlidesActions {
  const AiSlidesActions(this.repository, {this.generationAllowed});
  final Future<bool> Function(String ownerId)? generationAllowed;
  final AiSlidesRepository repository;
  Future<AiSlidesAccess> access() => repository.access();
  Future<AiSlidesResult> generate(String prompt, {String ownerId = ''}) async {
    if (prompt.trim().isEmpty || prompt.length > 6000) {
      throw const AiSlidesFailure('수업 내용을 1~6,000자로 입력해 주세요.');
    }
    if (generationAllowed != null && !await generationAllowed!(ownerId)) {
      throw const AiSlidesFailure(
        '내용 정리를 잠시 점검하고 있어요. 템플릿과 직접 편집은 계속 사용할 수 있어요.',
      );
    }
    final access = await repository.access();
    if (!access.canRequest) {
      throw const AiSlidesFailure('AI 슬라이드 도우미는 Plus와 Premium에서 이용할 수 있어요.');
    }
    if (!access.enabled) {
      throw const AiSlidesFailure('내용 정리 기능을 준비 중이에요. 직접 입력해서 만들 수 있어요.');
    }
    // A server cache hit remains free even after the monthly quota is exhausted.
    return repository.generate(prompt.trim());
  }
}

WorkoutModule confirmAiSlide(AiSlideDraft draft, String id) {
  // Creating the artwork does not require configuring a timer. Preserve only
  // timings supplied in the notes; otherwise use the normal new-slide defaults.
  final defaults = WorkoutModule.empty(id);
  final work = draft.workSeconds ?? defaults.workSeconds;
  final rest = draft.restSeconds ?? defaults.restSeconds;
  final sets = draft.sets ?? defaults.sets;
  if (work < 1 ||
      work > 3600 ||
      rest < 0 ||
      rest > 3600 ||
      sets < 1 ||
      sets > 100) {
    throw const AiSlidesFailure('타이머 정보를 읽지 못했어요. 수업 내용을 다시 정리해 주세요.');
  }
  final module = previewAiSlide(draft, id);
  if (!hasSlideDesign(module)) throw const AiSlidesFailure('슬라이드 배치를 선택해 주세요.');
  final error = slideDesignError(module);
  if (error != null) throw AiSlidesFailure(error);
  return module;
}

/// Preview keeps incomplete edits visible; confirmation validates the draft.
WorkoutModule previewAiSlide(AiSlideDraft draft, [String id = 'ai-preview']) {
  final defaults = WorkoutModule.empty(id);
  return defaults.copyWith(
    name: draft.title.trim(),
    text: draft.lines.join('\n'),
    // Older clients use the exported PNG when they do not know this renderer.
    designTemplate:
        '${draft.designStyle == null ? 'stationd-v2' : 'studio-v1'}-${draft.layout}',
    designStyle: draft.designStyle,
    designHeaderLabel: draft.designHeaderLabel,
    designSubtitle: draft.designSubtitle,
    designBackgroundColor: draft.designBackgroundColor,
    designTextColor: draft.designTextColor,
    designAccentColor: draft.designAccentColor,
    designLayout: draft.designLayout,
    designFontWeight: draft.designFontWeight,
    designItalic: draft.designItalic,
    designSpacing: draft.designSpacing,
    showTimer: draft.showTimer,
    showSets: draft.showTimer,
    workSeconds: draft.workSeconds ?? defaults.workSeconds,
    restSeconds: draft.restSeconds ?? defaults.restSeconds,
    sets: draft.sets ?? defaults.sets,
    appearance: SlideAppearance(
      timerX: draft.timerX,
      timerY: draft.timerY,
      timerSize: draft.timerSize,
      showTitle: false,
      showBody: false,
      setsColor: draft.designTextColor ?? 0xB3FFFFFF,
    ),
  );
}
