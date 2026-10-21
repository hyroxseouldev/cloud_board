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
  TemplateJobsActions get _actions => ref.read(templateJobsActionsProvider);
  bool _current(Object value) => ref.mounted && identical(_lifetime, value);
  @override
  TemplateJobsState build() {
    ref.watch(aiSlidesOwnerIdProvider);
    final scope = ref.watch(centerSlideCatalogScopeProvider);
    ref.watch(templateJobsActionsProvider);
    final lifetime = _lifetime = Object();
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
        state = state.copyWith(unresolved: pending.value ?? pending.hasError);
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
  }

  void _error(Object error) {
    final code = error is AiSlidesFailure
        ? error.code
        : error is FirebaseException
        ? error.code
        : null;
    final revoked = ['permission-denied', 'unauthenticated'].contains(code);
    state = state.copyWith(
      loading: false,
      submitting: revoked ? false : state.submitting,
      opening: revoked ? false : state.opening,
      authorityDenied: revoked || state.authorityDenied,
      jobs: revoked ? [] : state.jobs,
      usage: revoked ? null : state.usage,
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
    if (state.submitting || state.unresolved) return;
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
    await _send(() async {
      await ref.read(slideStudioActionsProvider).requireGeneration();
      return _actions.enqueue(input, 'template-${newId()}');
    }, accepted: input);
  }

  Future<void> retry(TemplateJob job) async {
    if (state.submitting ||
        state.unresolved ||
        job.status != 'failed' ||
        !job.retryable) {
      return;
    }
    await _send(() async {
      await ref.read(slideStudioActionsProvider).requireGeneration();
      return _actions.retry(job, 'template-${newId()}');
    });
  }

  Future<void> recover() async {
    if (state.submitting) return;
    await _send(_actions.recover);
  }

  Future<void> _send(
    Future<TemplateJobsReply?> Function() action, {
    StudioInput? accepted,
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
    if (reply != null) _merge(reply.jobs);
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
