import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_raster_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';

part 'slide_studio_controller.g.dart';

@riverpod
class SlideStudioController extends _$SlideStudioController {
  Object _lifetime = Object();
  Timer? _reset;
  int _usageRevision = 0;
  Uint8List? _pendingReference;
  @override
  SlideStudioState build() {
    ref.watch(aiSlidesOwnerIdProvider);
    ref.watch(centerSlideCatalogScopeProvider);
    ref.watch(slideStudioActionsProvider);
    _lifetime = Object();
    ref.onDispose(() {
      _lifetime = Object();
      _reset?.cancel();
      _pendingReference = null;
    });
    return SlideStudioState(
      input: StudioInput(design: aiSlideDesignCatalog.first),
      usageLoading: false,
    );
  }

  bool _current(Object lifetime) =>
      ref.mounted && identical(lifetime, _lifetime);
  SlideStudioActions get _actions => ref.read(slideStudioActionsProvider);
  AiRasterActions get _raster => ref.read(aiRasterActionsProvider);

  void edit(StudioInput input) =>
      state = state.copyWith(input: input, error: null);
  void select(AiSlideDesign design) =>
      edit(state.input.copyWith(design: design));
  void reference(Uint8List? bytes) {
    final copy = bytes == null ? null : Uint8List.fromList(bytes);
    state = state.copyWith(
      reference: copy,
      input: state.input.copyWith(
        referenceHash: copy == null ? null : sha256.convert(copy).toString(),
      ),
      error: null,
    );
  }

  void reportError(String message) => state = state.copyWith(error: message);
  void _error(Object error) {
    final revoked =
        error is AiSlidesFailure &&
        ['permission-denied', 'unauthenticated'].contains(error.code);
    state = state.copyWith(
      busy: false,
      saving: false,
      error: error is AiSlidesFailure
          ? error.message
          : error is FormatException
          ? error.message
          : workoutErrorMessage(
              error,
              fallback: '처리하지 못했어요. 입력과 이전 결과는 유지됩니다.',
            ),
      result: revoked ? null : state.result,
      history: revoked ? [] : state.history,
      brand: revoked ? null : state.brand,
      pendingId: revoked ? null : state.pendingId,
      pendingInput: revoked ? null : state.pendingInput,
      completedOperation: revoked ? null : state.completedOperation,
    );
  }

  Future<void> loadBrand() async {
    final lifetime = _lifetime;
    final value = await AsyncValue.guard(_raster.context);
    if (!_current(lifetime)) return;
    state = state.copyWith(
      brand: value.value?.brand,
      brandError: value.hasError
          ? '센터 AI 배경을 준비 중이에요. 원본 템플릿은 계속 사용할 수 있어요.'
          : null,
    );
  }

  Future<void> refreshUsage({String? requestId, bool raster = false}) async {
    final lifetime = _lifetime, revision = ++_usageRevision;
    state = state.copyWith(usageLoading: true);
    final value = await AsyncValue.guard(
      () => _actions.usage(requestId: requestId, raster: raster),
    );
    if (!_current(lifetime) || revision != _usageRevision) return;
    state = state.copyWith(
      usageLoading: false,
      usage: value.value ?? state.usage,
      usageError: value.hasError ? '사용량을 갱신하지 못했어요. 마지막 확인 값입니다.' : null,
    );
    _reset?.cancel();
    final duration = state.usage?.resetsAt?.difference(DateTime.now());
    if (!value.hasError && duration != null && duration > Duration.zero) {
      _reset = Timer(duration, refreshUsage);
    }
  }

  void _accept(StudioResult result) {
    if (state.input != result.input) {
      state = state.copyWith(
        busy: false,
        pendingId: null,
        pendingInput: null,
        completedOperation: null,
        history: [result, ...state.history].take(3).toList(),
        error: '생성 중 입력이 바뀌어 기존 결과를 유지했어요. 이전 결과 보기에서 완성된 시안을 확인할 수 있어요.',
      );
      return;
    }
    state = state.copyWith(
      busy: false,
      pendingId: null,
      pendingInput: null,
      completedOperation: null,
      result: result,
      history: [
        if (state.result != null) state.result!,
        ...state.history,
      ].take(3).toList(),
      error: null,
    );
  }

  /// This screen never resumes a paid operation, including restored old modes.
  /// The legacy operations remain available to their existing callers.
  Future<void> generateTemplate() async {
    if (state.busy || state.saving) return;
    _pendingReference = null;
    state = state.copyWith(
      input: state.input.copyWith(
        mode: StudioMode.template,
        brief: '',
        referenceHash: null,
      ),
      reference: null,
      pendingId: null,
      pendingInput: null,
      pendingRaster: false,
      completedOperation: null,
      error: null,
    );
    await generate();
  }

  Future<void> generate() async {
    if (state.busy || state.saving || state.pendingId != null) return;
    final lifetime = _lifetime, input = state.input;
    final reference = state.reference, brand = state.brand;
    if (input.raw.trim().isEmpty ||
        input.raw.length > 6000 ||
        input.title.trim().isEmpty ||
        input.title.length > 60 ||
        input.subtitle.length > 120 ||
        input.brief.length > 1000) {
      reportError('제목(1~60자), 운동 안내(120자 이내), 수업 내용(1~6,000자)을 확인해 주세요.');
      return;
    }
    final recipe = input.design.theme.centerRecipe;
    if (input.mode == StudioMode.organize && !studioSupportsGroups(input)) {
      reportError(studioGroupingUnavailable);
      return;
    }
    if (recipe != null) {
      final catalog = ref.read(centerSlideCatalogProvider);
      if (catalog.isLoading ||
          catalog.hasError ||
          !(catalog.value?.templates.any((d) => d == input.design) ?? false)) {
        reportError('센터 디자인이 갱신되었거나 권한을 확인하지 못했어요. 다시 선택해 주세요.');
        return;
      }
    }
    if (input.mode == StudioMode.artwork &&
        (state.brand == null ||
            recipe?.templateId != state.brand!.templateId ||
            recipe?.revision != state.brand!.recipeRevision)) {
      reportError('AI 배경 생성은 승인된 센터 참고 디자인을 선택해 주세요. 다른 디자인은 템플릿으로 사용할 수 있어요.');
      return;
    }
    state = state.copyWith(busy: true, error: null);
    final id = 'studio-${newId()}';
    if (input.mode == StudioMode.template) {
      final draft = studioDraft(input);
      final checked = await AsyncValue.guard(() => _actions.validate(draft));
      if (!_current(lifetime)) return;
      if (checked.hasError) {
        _error(checked.error!);
        return;
      }
      _accept(
        StudioResult(id: id, input: input, reference: reference, draft: draft),
      );
      return;
    }
    if (input.mode == StudioMode.organize) {
      // Reject input that already overflows before spending a request. Group
      // headings are measured again after completion without discarding it.
      final checked = await AsyncValue.guard(
        () => _actions.validate(studioDraft(input)),
      );
      if (!_current(lifetime)) return;
      if (checked.hasError) {
        _error(checked.error!);
        return;
      }
    }
    final allowed = await AsyncValue.guard(_actions.requireGeneration);
    if (!_current(lifetime)) return;
    if (allowed.hasError) {
      _error(allowed.error!);
      return;
    }
    _pendingReference = reference;
    state = state.copyWith(
      pendingId: id,
      pendingInput: input,
      pendingRaster: input.mode == StudioMode.artwork,
    );
    if (input.mode == StudioMode.artwork) {
      final lines = rasterSourceLines(input.raw);
      final count = input.artworkGroups.clamp(1, lines.length.clamp(1, 3));
      final draft = AiRasterDraft(
        rawWod: input.raw,
        title: input.title,
        brief: input.brief,
        bodyFontSize: input.artworkFontSize,
        groups: [
          for (var i = 0; i < count; i++)
            AiRasterGroup(
              heading: count == 1 ? '' : String.fromCharCode(65 + i),
              lines: lines.sublist(
                (i * lines.length / count).floor(),
                ((i + 1) * lines.length / count).floor(),
              ),
            ),
        ],
      );
      final value = await AsyncValue.guard(() {
        _actions.validateArtwork(draft, brand!);
        return _raster.generate(
          draft,
          brand,
          id,
          state.result?.brand == brand ? state.result?.job?.requestId : null,
        );
      });
      if (!_current(lifetime)) return;
      if (value.hasError) {
        _requestError(value.error!);
      } else {
        _acceptRaster(value.requireValue, input);
      }
    } else {
      final value = await AsyncValue.guard(
        () => _actions.generate(
          input,
          id,
          input.mode == StudioMode.style ? reference : null,
        ),
      );
      if (!_current(lifetime)) return;
      if (value.hasError) {
        _requestError(value.error!);
      } else {
        await _acceptOperation(value.requireValue, input);
      }
    }
    if (_current(lifetime)) {
      unawaited(
        refreshUsage(requestId: id, raster: input.mode == StudioMode.artwork),
      );
    }
  }

  void _requestError(Object error) {
    _error(error);
    if (error is AiSlidesFailure &&
        [
          'invalid-argument',
          'failed-precondition',
          'resource-exhausted',
          'permission-denied',
          'not-found',
        ].contains(error.code)) {
      state = state.copyWith(pendingId: null, pendingInput: null);
    } // Unknown transport outcome keeps its ID; retry below is read-only.
  }

  void _acceptRaster(AiRasterReply value, StudioInput input) {
    if (value.job.brandKey != state.brand?.key) {
      _error(
        const AiSlidesFailure(
          '센터 참고 디자인이 변경되었어요. 다시 선택해 주세요.',
          code: 'permission-denied',
        ),
      );
      return;
    }
    if (value.job.status != 'completed') {
      state = state.copyWith(
        busy: false,
        error: value.job.message ?? '생성 결과를 확인 중이에요.',
        pendingId: value.job.status == 'failed' ? null : value.job.requestId,
      );
      return;
    }
    _accept(
      StudioResult(
        id: value.job.requestId,
        input: input,
        reference: _pendingReference,
        job: value.job,
        brand: state.brand,
      ),
    );
  }

  Future<void> _acceptOperation(
    StudioOperation value,
    StudioInput input, {
    bool reapplying = false,
  }) async {
    if (value.status != 'completed') {
      state = state.copyWith(
        busy: false,
        error: value.message ?? '생성 결과를 확인 중이에요.',
        pendingId: value.status == 'rejected' ? null : value.requestId,
      );
      return;
    }
    final lifetime = _lifetime;
    final editedSource =
        reapplying &&
        (input.raw != state.pendingInput?.raw ||
            input.brief != state.pendingInput?.brief);
    final reference = reapplying ? state.reference : _pendingReference;
    state = state.copyWith(completedOperation: value);
    if (!editedSource &&
        value.groups.isNotEmpty &&
        !studioSupportsGroups(input)) {
      reportError(studioGroupingUnavailable);
      state = state.copyWith(busy: false);
      return;
    }
    final applied = editedSource
        ? input.copyWith(mode: StudioMode.template)
        : value.designs.isEmpty || reapplying
        ? input
        : input.copyWith(design: value.designs.first);
    final draft = studioDraft(
      applied,
      groups: value.groups.isEmpty || editedSource ? null : value.groups,
    );
    final checked = await AsyncValue.guard(() => _actions.validate(draft));
    if (!_current(lifetime)) return;
    state = state.copyWith(
      proposals: value.designs.isEmpty ? state.proposals : value.designs,
    );
    if (checked.hasError) {
      _error(checked.error!);
      return;
    }
    if (editedSource && state.input == input) {
      state = state.copyWith(input: applied);
    }
    _accept(
      StudioResult(
        id: value.requestId,
        input: editedSource ? applied : input,
        reference: reference,
        draft: draft,
        warnings: [
          ...value.warnings,
          if (editedSource) '수정한 입력은 AI에 다시 보내지 않고 무료 템플릿으로 적용했어요. 이전 AI 그룹은 자동 적용하지 않았고 추가 차감은 없어요.',
        ],
      ),
    );
  }

  Future<void> retry() async {
    final id = state.pendingId,
        input = state.pendingInput,
        lifetime = _lifetime;
    if (id == null || input == null || state.busy) return;
    state = state.copyWith(busy: true, error: null);
    final completed = state.completedOperation;
    if (completed != null) {
      if (state.input.mode != input.mode ||
          input.mode == StudioMode.style &&
              (state.input.brief != input.brief ||
                  state.input.referenceHash != input.referenceHash)) {
        state = state.copyWith(
          busy: false,
          error: '완료된 요청과 같은 생성 방식에서 다시 적용해 주세요. 새 AI 요구사항은 새 요청으로 생성해야 해요.',
        );
        return;
      }
      await _acceptOperation(completed, state.input, reapplying: true);
      return; // Completed receipt reuse never calls generate or status again.
    }
    if (state.pendingRaster) {
      final value = await AsyncValue.guard(() => _raster.status(id));
      if (!_current(lifetime)) return;
      if (value.hasError) {
        _error(value.error!);
      } else {
        _acceptRaster(value.requireValue, input);
      }
    } else {
      final value = await AsyncValue.guard(
        () => _actions.status(
          id,
          reference:
              input.mode == StudioMode.style && input.referenceHash != null,
        ),
      );
      if (!_current(lifetime)) return;
      if (value.hasError) {
        _error(value.error!);
      } else {
        await _acceptOperation(value.requireValue, input);
      }
    }
    if (_current(lifetime)) {
      unawaited(
        refreshUsage(requestId: id, raster: input.mode == StudioMode.artwork),
      );
    }
  }

  void newRequest() {
    if (state.busy) return;
    state = state.copyWith(
      pendingId: null,
      pendingInput: null,
      completedOperation: null,
      error: null,
    );
  }

  void undo() {
    if (state.busy || state.saving || state.history.isEmpty) return;
    final previous = state.history.first;
    state = state.copyWith(
      input: previous.input,
      reference: previous.reference,
      result: previous,
      history: state.history.skip(1).toList(),
      error: null,
    );
  }

  Future<WorkoutModule?> add() async {
    if (state.busy ||
        state.saving ||
        state.pendingId != null ||
        state.dirty ||
        state.result == null) {
      return null;
    }
    final lifetime = _lifetime, snapshot = state.result!;
    state = state.copyWith(saving: true, error: null);
    final value = await AsyncValue.guard(() => _actions.prepare(snapshot));
    if (!_current(lifetime)) return null;
    state = state.copyWith(saving: false);
    if (value.hasError) {
      _error(value.error!);
      return null;
    }
    if (state.result != snapshot || state.dirty) return null;
    state = state.copyWith(leaving: true);
    return value.requireValue;
  }

  Future<void> save() async {
    if (state.busy ||
        state.saving ||
        state.pendingId != null ||
        state.dirty ||
        state.result == null ||
        state.result!.savedModule != null) {
      return;
    }
    final lifetime = _lifetime, snapshot = state.result!;
    state = state.copyWith(saving: true, error: null);
    final value = await AsyncValue.guard(
      () async => _actions.save(await _actions.prepare(snapshot)),
    );
    if (!_current(lifetime)) return;
    state = state.copyWith(saving: false);
    if (value.hasError) {
      _error(value.error!);
      return;
    }
    if (state.result == snapshot) {
      state = state.copyWith(
        result: snapshot.copyWith(savedModule: value.requireValue),
      );
    }
  }

  void openSaved(WorkoutModule module) {
    if (state.busy || state.saving) return;
    state = state.copyWith(leaving: true);
  }
}
