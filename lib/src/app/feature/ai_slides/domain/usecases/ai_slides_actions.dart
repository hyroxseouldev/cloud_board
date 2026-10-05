import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
part 'ai_slides_actions.g.dart';

@riverpod
AiSlidesActions aiSlidesActions(Ref ref) =>
    AiSlidesActions(ref.watch(aiSlidesRepositoryProvider));

class AiSlidesActions {
  const AiSlidesActions(this.repository);
  final AiSlidesRepository repository;
  Future<AiSlidesAccess> access() => repository.access();
  Future<AiSlidesResult> generate(String prompt) async {
    if (prompt.trim().isEmpty || prompt.length > 6000) {
      throw const AiSlidesFailure('수업 내용을 1~6,000자로 입력해 주세요.');
    }
    final access = await repository.access();
    if (!access.premium) throw const AiSlidesFailure('프리미엄 이용자만 사용할 수 있어요.');
    if (!access.enabled) throw const AiSlidesFailure('AI 기능을 준비 중입니다.');
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
    throw const AiSlidesFailure('타이머 정보를 읽지 못했어요. 다시 생성해 주세요.');
  }
  final module = defaults.copyWith(
    name: draft.title.trim(),
    text: draft.lines.join('\n'),
    designTemplate: 'stationd-v1-${draft.layout}',
    designBackgroundColor: draft.designBackgroundColor,
    designTextColor: draft.designTextColor,
    designAccentColor: draft.designAccentColor,
    workSeconds: work,
    restSeconds: rest,
    sets: sets,
    appearance: SlideAppearance(
      showTitle: false,
      showBody: false,
      setsColor: draft.designTextColor ?? 0xB3FFFFFF,
    ),
  );
  if (!hasSlideDesign(module)) throw const AiSlidesFailure('슬라이드 배치를 선택해 주세요.');
  final error = slideDesignError(module);
  if (error != null) throw AiSlidesFailure(error);
  return module;
}
