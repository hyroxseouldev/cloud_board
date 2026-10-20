import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy.dart';
import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy_service.dart';

import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/slide_studio_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/slide_studio_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'slide_studio_actions.g.dart';

@riverpod
SlideStudioActions slideStudioActions(Ref ref) => SlideStudioActions(
  ref.watch(slideStudioRepositoryProvider),
  generationAllowed: () => ref
      .read(runtimeFeaturePolicyServiceProvider)
      .allows(
        RuntimeFeature.aiSlideGeneration,
        ownerId: ref.read(aiSlidesOwnerIdProvider) ?? '',
      ),
);

class SlideStudioActions {
  const SlideStudioActions(this.repository, {this.generationAllowed});
  final SlideStudioRepository? repository;
  final Future<bool> Function()? generationAllowed;
  Future<void> requireGeneration() async {
    if (generationAllowed != null && !await generationAllowed!()) {
      throw const AiSlidesFailure(
        'AI 생성을 잠시 점검하고 있어요. 템플릿은 사용할 수 있어요.',
        code: 'failed-precondition',
      );
    }
  }

  SlideStudioRepository get _repository =>
      repository ??
      (throw const AiSlidesFailure(
        '로그인한 센터에서 다시 열어 주세요.',
        code: 'permission-denied',
      ));
  Future<StudioUsage> usage({String? requestId, bool raster = false}) =>
      _repository.usage(requestId: requestId, raster: raster);
  Future<StudioOperation> generate(
    StudioInput input,
    String id,
    Uint8List? reference,
  ) => _repository.generate(input, id, reference);
  Future<StudioOperation> status(String id, {required bool reference}) =>
      _repository.status(id, reference: reference);
  Future<void> validate(AiSlideDraft draft) => _repository.validate(draft);
  void validateArtwork(AiRasterDraft draft, AiRasterBrand brand) =>
      _repository.validateArtwork(draft, brand);
  Future<WorkoutModule> prepare(StudioResult result) =>
      _repository.prepare(result);
  Future<WorkoutModule> save(WorkoutModule module) => _repository.save(module);
}

/// Template samples supply visual identity only. Today's raw WOD replaces every
/// sample exercise; no parser requires a special markdown/section syntax.
AiSlideDraft studioDraft(StudioInput input, {List<AiRasterGroup>? groups}) {
  final theme = input.design.theme;
  final base = input.design.sample ?? initialAiSlideDesignDraft(theme);
  var lines = input.raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  if (theme.centerRecipe?.body != null && groups != null && groups.length > 1) {
    lines = [
      for (final group in groups) ...[
        if (group.heading.isNotEmpty) '## ${group.heading}',
        ...group.lines,
      ],
    ];
  }
  return applyAiSlideTheme(
    base.copyWith(
      title: input.title,
      lines: lines,
      designSubtitle: '',
      // Blank timing is intentional: input text is never interpreted as a change
      // to a lesson's duration or drawn as a raster clock.
      workSeconds: null,
      restSeconds: null,
      sets: null,
    ),
    theme,
  ).copyWith(showTimer: false);
}
