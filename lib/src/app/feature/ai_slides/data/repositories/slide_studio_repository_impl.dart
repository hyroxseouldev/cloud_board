import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/ai_timer/data/datasources/ai_timer_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/slide_editor_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/slide_studio_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_creation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_template_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/slide_studio_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/slide_studio_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/ai_raster_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_raster_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';

part 'slide_studio_repository_impl.g.dart';

@riverpod
SlideStudioRepository? slideStudioRepository(Ref ref) {
  final scope = ref.watch(centerSlideCatalogScopeProvider);
  final owner = ref.watch(aiSlidesOwnerIdProvider);
  if (owner == null) return null;
  final auth = ref.watch(firebaseClientAuthProvider);
  var active = true;
  ref.onDispose(() => active = false);
  return SlideStudioRepositoryImpl(
    source: SlideStudioDataSource(
      FirebaseFunctions.instanceFor(app: auth.app, region: 'asia-northeast3'),
      scope?.centerId ?? '',
      () =>
          active &&
          ref.mounted &&
          auth.currentUser?.uid == owner &&
          ref.read(aiSlidesOwnerIdProvider) == owner &&
          ref.read(centerSlideCatalogScopeProvider) == scope,
    ),
    ownerId: owner,
    center: ref.watch(centerSlideTemplateActionsProvider),
    raster: ref.watch(aiRasterRepositoryProvider),
    library: ref.watch(slideEditorRepositoryProvider),
    legacy: ref.watch(aiSlidesRepositoryProvider),
  );
}

class SlideStudioRepositoryImpl implements SlideStudioRepository {
  SlideStudioRepositoryImpl({
    required this.source,
    required this.ownerId,
    required this.center,
    required this.raster,
    required this.library,
    required this.legacy,
  });
  final SlideStudioDataSource source;
  final String ownerId;
  final CenterSlideTemplateActions center;
  final AiRasterRepository? raster;
  final SlideEditorRepository library;
  final AiSlidesRepository legacy;
  String? _preparedId;
  WorkoutModule? _prepared;

  void _guard() {
    if (!source.isCurrent()) {
      throw const AiSlidesFailure(
        '계정 또는 센터가 변경되었어요.',
        code: 'permission-denied',
      );
    }
  }

  @override
  Future<StudioUsage> usage({String? requestId, bool raster = false}) async {
    if (source.centerId.isEmpty) return _legacyUsage();
    try {
      return readStudioUsage(
        await source.call('usage', {
          'requestId': ?requestId,
          'kind': raster ? 'raster' : 'studio',
        }),
      );
    } on AiSlidesFailure catch (error) {
      if (error.code != 'not-found') rethrow;
      // A not-yet-deployed additive endpoint does not remove the old allowance.
      return _legacyUsage();
    }
  }

  Future<StudioUsage> _legacyUsage() async {
    final access = await legacy.access();
    _guard();
    return StudioUsage(
      allowed: access.canRequest,
      enabled: access.enabled,
      used: access.usedRequests,
      remaining: access.remaining,
      limit: access.limit,
      resetsAt: access.resetsAt,
      availabilityReason: access.availabilityReason,
    );
  }

  @override
  Future<StudioOperation> generate(
    StudioInput input,
    String requestId,
    Uint8List? reference,
  ) async {
    final fields = <String, dynamic>{
      'requestId': requestId,
      'operation': input.mode == StudioMode.organize ? 'organize' : 'style',
    };
    if (input.mode == StudioMode.organize) {
      fields.addAll({'rawWod': input.raw, 'brief': input.brief});
    } else {
      final theme = input.design.theme;
      fields['prompt'] =
          '${input.brief}\n선택한 디자인: ${input.design.name}. ${input.design.description}. '
          '배경색 ${theme.designBackgroundColor}, 본문색 ${theme.designTextColor}, 강조색 ${theme.designAccentColor}, '
          '배치 ${theme.designLayout}, 서체 ${theme.designStyle?.fontFamily}, 제목 굵기 ${theme.designStyle?.titleWeight}. '
          '선택한 디자인의 시각적 특징을 참고하고 운동 내용과 타이머 숫자는 만들지 마세요.';
      if (reference != null) {
        fields['imageBase64'] = base64Encode(
          await compute(prepareAiTimerImage, reference),
        );
        fields['mimeType'] = 'image/jpeg';
      }
    }
    _guard();
    return readStudioOperation(
      await source.call('generate', fields),
      reference: reference != null,
    );
  }

  @override
  Future<StudioOperation> status(
    String requestId, {
    required bool reference,
  }) async => readStudioOperation(
    await source.call('status', {'requestId': requestId}),
    reference: reference,
  );

  @override
  void validateArtwork(AiRasterDraft draft, AiRasterBrand brand) {
    _guard();
    final error = rasterDraftError(draft) ?? rasterLayoutError(draft, brand);
    if (error != null) throw AiSlidesFailure(error, code: 'invalid-argument');
  }

  @override
  Future<void> validate(AiSlideDraft draft) async {
    _guard();
    if (draft.centerRecipe != null) {
      final error = centerSlideDraftError(draft);
      if (error != null) throw AiSlidesFailure(error);
      await center.loadBackground(draft.centerRecipe!);
      final layout = prepareCenterSlideLayout(draft.centerRecipe!, draft);
      layout.dispose();
    } else {
      final module = previewAiSlide(draft);
      final error = slideDesignError(module);
      if (error != null) throw AiSlidesFailure(error);
      final metrics = measureSlideDesign(module, creationTypography: true);
      if (!metrics.readable || metrics.warning != null) {
        throw AiSlidesFailure(
          metrics.warning ?? '내용이 넘쳐요. 문구를 줄이거나 슬라이드를 나눠 주세요.',
        );
      }
    }
    _guard();
  }

  @override
  Future<WorkoutModule> prepare(StudioResult result) async {
    _guard();
    if (result.job != null) {
      if (raster == null || result.brand == null) {
        throw const AiSlidesFailure('센터 이미지 연결을 확인해 주세요.');
      }
      return (await raster!.createModule(
        result.job!,
        result.brand!,
      )).copyWith(id: result.id);
    }
    final draft = result.draft!;
    await validate(draft);
    if (_preparedId == result.id && _prepared != null) return _prepared!;
    final value = draft.centerRecipe != null
        ? confirmCenterSlide(draft, result.id, await center.renderDraft(draft))
        : await prepareCreatedSlideDesign(confirmAiSlide(draft, result.id));
    _guard();
    // Retain the original paste for library reopening; the completed PNG owns
    // any display-only group labels. No private recipe enters old documents.
    _prepared = draft.centerRecipe != null
        ? value.copyWith(
            text: result.input.raw,
            appearance: value.appearance.copyWith(showBrand: false),
          )
        : value;
    _preparedId = result.id;
    return _prepared!;
  }

  @override
  Future<WorkoutModule> save(WorkoutModule module) async {
    _guard();
    final before = await library.loadTemplates(ownerId);
    _guard();
    final existing = before.where((item) => item.id == module.id).firstOrNull;
    if (existing != null) {
      return existing; // Stable result ID after response loss.
    }
    final saved = await library.saveTemplates(ownerId, [
      ...before,
      module,
    ], previous: before);
    _guard();
    return saved.singleWhere((item) => item.id == module.id);
  }
}
