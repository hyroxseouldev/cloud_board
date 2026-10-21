import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/template_jobs_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

part 'template_jobs_controller.g.dart';

@riverpod
class TemplateJobsController extends _$TemplateJobsController {
  Object _lifetime = Object();
  int _listRevision = 0;
  StreamSubscription<List<TemplateJob>>? _subscription;
  String? _assetAttempt;
  Object? _assetRead;
  TemplateJobsActions get _actions => ref.read(templateJobsActionsProvider);
  bool _current(Object value) => ref.mounted && identical(_lifetime, value);
  @override
  TemplateJobsState build() {
    ref.watch(aiSlidesOwnerIdProvider);
    final scope = ref.watch(centerSlideCatalogScopeProvider);
    ref.watch(templateJobsActionsProvider);
    final lifetime = _lifetime = Object();
    _assetAttempt = null;
    _assetRead = null;
    ref.onDispose(() {
      _lifetime = Object();
      _subscription?.cancel();
    });
    if (scope == null) return const TemplateJobsState(loading: false);
    Future.microtask(() async {
      if (!_current(lifetime)) return;
      try {
        _subscription = _actions.watch().listen(
          (jobs) {
            if (!_current(lifetime)) return;
            final finished = jobs.any(
              (job) =>
                  !job.inProgress &&
                  state.jobs.any(
                    (old) => old.requestId == job.requestId && old.inProgress,
                  ),
            );
            _merge(jobs);
            if (finished) unawaited(refresh());
          },
          onError: (Object error) {
            if (_current(lifetime)) _error(error);
          },
        );
      } catch (error) {
        if (_current(lifetime)) _error(error);
      }
      await refresh();
      if (!_current(lifetime)) return;
      // Recovery is explicit if a previous acknowledgement was lost: never
      // silently submit work just because a screen was opened.
      final pending = await AsyncValue.guard(_actions.hasUnresolved);
      if (_current(lifetime)) {
        state = state.copyWith(
          unresolved: pending.value ?? pending.hasError,
          recoveryChecked: true,
        );
      }
    });
    return const TemplateJobsState();
  }

  void _merge(List<TemplateJob> jobs) {
    final byId = {for (final job in state.jobs) job.requestId: job};
    for (final job in jobs) {
      final before = byId[job.requestId];
      if (before == null || job.updatedAtMs >= before.updatedAtMs) {
        byId[job.requestId] = job;
      }
    }
    final sorted = byId.values.toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    state = state.copyWith(jobs: sorted);
    unawaited(_loadCurrentAsset());
  }

  /// Selection is explicit on this screen; history refreshes never select a job.
  void selectResult(TemplateJob job) {
    // A management-page selection may be older than the first list page.
    _merge([job]);
    selectCurrent(job.requestId);
  }

  void selectCurrent(String? requestId) {
    if (state.currentRequestId == requestId) return;
    _assetRead = null;
    _assetAttempt = null;
    state = state.copyWith(
      currentRequestId: requestId,
      currentPng: null,
      currentAssetLoading: false,
      currentAssetError: null,
    );
    unawaited(_loadCurrentAsset());
  }

  Future<void> retryCurrentAsset() async {
    if (state.currentAssetLoading == true) return;
    _assetAttempt = null;
    await _loadCurrentAsset();
  }

  Future<void> _loadCurrentAsset() async {
    final job = state.currentJob;
    if (job == null || !job.complete || state.authorityDenied) return;
    final key = '${job.requestId}:${job.sha256}';
    if (_assetAttempt == key) return;
    _assetAttempt = key; // Failure stays latched until an explicit retry.
    final read = _assetRead = Object(), lifetime = _lifetime;
    state = state.copyWith(
      currentPng: null,
      currentAssetLoading: true,
      currentAssetError: null,
      error: null,
    );
    final value = await AsyncValue.guard(() => _actions.asset(job));
    if (!_current(lifetime) ||
        !identical(read, _assetRead) ||
        state.currentRequestId != job.requestId) {
      return;
    }
    if (value.hasError) {
      _error(value.error!);
      state = state.copyWith(
        currentAssetLoading: false,
        currentAssetError: state.error,
      );
      return;
    }
    state = state.copyWith(
      currentPng: value.requireValue,
      currentAssetLoading: false,
      currentAssetError: null,
    );
  }

  void _error(Object error) {
    final code = error is AiSlidesFailure
        ? error.code
        : error is FirebaseException
        ? error.code
        : null;
    final revoked = ['permission-denied', 'unauthenticated'].contains(code);
    if (revoked) {
      _assetRead = null;
      _assetAttempt = null;
    }
    state = state.copyWith(
      loading: false,
      submitting: revoked ? false : state.submitting,
      opening: revoked ? false : state.opening,
      authorityDenied: revoked || state.authorityDenied,
      jobs: revoked ? [] : state.jobs,
      usage: revoked ? null : state.usage,
      currentPng: revoked ? null : state.currentPng,
      currentAssetLoading: revoked ? false : state.currentAssetLoading,
      error: error is AiSlidesFailure
          ? error.message
          : '생성 작업을 불러오지 못했어요. 입력과 이전 결과는 유지됩니다.',
    );
  }

  Future<void> refresh() async {
    if (ref.read(centerSlideCatalogScopeProvider) == null) return;
    final lifetime = _lifetime, revision = ++_listRevision;
    state = state.copyWith(loading: true);
    final value = await AsyncValue.guard(_actions.list);
    if (!_current(lifetime) || revision != _listRevision) return;
    if (value.hasError) {
      _error(value.error!);
      return;
    }
    final firstPage = state.jobs.length <= 20;
    _merge(value.requireValue.jobs);
    state = state.copyWith(
      loading: false,
      authorityDenied: false,
      usage: value.requireValue.usage,
      nextCursor: firstPage ? value.requireValue.nextCursor : state.nextCursor,
      error: null,
    );
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor, lifetime = _lifetime;
    if (cursor == null || state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    final value = await AsyncValue.guard(() => _actions.list(before: cursor));
    if (!_current(lifetime)) return;
    state = state.copyWith(loadingMore: false);
    if (value.hasError) {
      _error(value.error!);
      return;
    }
    _merge(value.requireValue.jobs);
    state = state.copyWith(
      nextCursor: value.requireValue.nextCursor,
      error: null,
    );
  }

  Future<void> enqueue(StudioInput input) async {
    if (state.submitting ||
        state.unresolved ||
        state.currentJob?.inProgress == true) {
      return;
    }
    if (input.subtitle.trim().isEmpty) {
      state = state.copyWith(error: '운동 안내 문구를 입력해 주세요.');
      return;
    }
    final catalog = ref.read(centerSlideCatalogProvider);
    if (input.design.theme.centerRecipe == null ||
        catalog.isLoading ||
        catalog.hasError ||
        !(catalog.value?.templates.contains(input.design) ?? false)) {
      state = state.copyWith(
        error: '센터 디자인이 변경되었거나 권한을 확인하지 못했어요. 다시 선택해 주세요.',
      );
      return;
    }
    final requestId = 'template-${newId()}';
    selectCurrent(requestId);
    await _send(() async {
      await ref.read(slideStudioActionsProvider).requireGeneration();
      return _actions.enqueue(input, requestId);
    }, accepted: input);
  }

  Future<void> retry(TemplateJob job) async {
    if (state.submitting ||
        state.unresolved ||
        state.currentJob?.inProgress == true ||
        job.status != 'failed' ||
        !job.retryable) {
      return;
    }
    final requestId = 'template-${newId()}';
    selectCurrent(requestId);
    await _send(() async {
      await ref.read(slideStudioActionsProvider).requireGeneration();
      return _actions.retry(job, requestId);
    });
  }

  Future<void> recover() async {
    if (state.submitting) return;
    await _send(_actions.recover, recovering: true);
  }

  Future<void> _send(
    Future<TemplateJobsReply?> Function() action, {
    StudioInput? accepted,
    bool recovering = false,
  }) async {
    final lifetime = _lifetime;
    state = state.copyWith(submitting: true, error: null);
    final value = await AsyncValue.guard(action);
    if (!_current(lifetime)) return;
    if (value.hasError) {
      state = state.copyWith(submitting: false);
      _error(value.error!);
      final unresolved = await AsyncValue.guard(_actions.hasUnresolved);
      if (_current(lifetime)) {
        state = state.copyWith(unresolved: unresolved.value ?? true);
      }
      return;
    }
    final reply = value.value;
    _listRevision++; // A receipt is newer than any list read started before it.
    if (reply != null) {
      if (recovering && reply.jobs.isNotEmpty) {
        selectCurrent(reply.jobs.first.requestId);
      }
      _merge(reply.jobs);
    }
    state = state.copyWith(
      submitting: false,
      loading: false,
      unresolved: false,
      acceptedInput: accepted ?? state.acceptedInput,
      usage: reply?.usage ?? state.usage,
      error: null,
    );
  }

  Future<Uint8List?> open(TemplateJob job) async {
    if (!job.complete || state.opening) return null;
    final lifetime = _lifetime;
    state = state.copyWith(opening: true, error: null);
    final value = await AsyncValue.guard(() => _actions.asset(job));
    if (!_current(lifetime)) return null;
    if (value.hasError) {
      state = state.copyWith(opening: false);
      _error(value.error!);
      return null;
    }
    state = state.copyWith(opening: false);
    return value.requireValue;
  }
}
