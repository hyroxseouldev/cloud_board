import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_raster_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
part 'ai_raster_controller.g.dart';

@riverpod
class AiRasterController extends _$AiRasterController {
  Object _lifetime = Object();
  @override
  AiRasterState build() {
    ref.watch(aiRasterActionsProvider);
    final lifetime = _lifetime = Object();
    ref.onDispose(() {
      _lifetime = Object();
    });
    Future.microtask(() {
      if (_current(lifetime)) load();
    });
    return const AiRasterState();
  }

  bool _current(Object lifetime) =>
      ref.mounted && identical(_lifetime, lifetime);
  AiRasterActions get _actions => ref.read(aiRasterActionsProvider);
  void _error(Object error) {
    final failure = error is AiSlidesFailure
        ? error
        : const AiSlidesFailure('처리를 완료하지 못했어요. 입력과 이전 시안은 남아 있어요.');
    final revoked =
        ['permission-denied', 'unauthenticated'].contains(failure.code) ||
        [
          'brand-stale',
          'center-permission',
          'account-changed',
        ].contains(failure.reason);
    state = state.copyWith(
      busy: false,
      loading: false,
      error: failure.message,
      result: revoked ? null : state.result,
      history: revoked ? [] : state.history,
      brand: revoked ? null : state.brand,
    );
  }

  Future<void> load() async {
    final lifetime = _lifetime;
    final response = await AsyncValue.guard(_actions.context);
    if (!_current(lifetime)) return;
    response.when(
      data: (context) {
        final recent = context.recent;
        final result = recent?.status == 'completed'
            ? recent
            : context.previous;
        state = state.copyWith(
          loading: false,
          brand: context.brand,
          allowed: context.allowed,
          enabled: context.enabled,
          remaining: context.remaining,
          limit: context.limit,
          draft: recent?.draft ?? state.draft,
          result: result,
          pendingRequestId: ['processing', 'uncertain'].contains(recent?.status)
              ? recent!.requestId
              : null,
          pendingStatus: recent?.status,
          error: recent?.message,
        );
      },
      error: (error, _) => _error(error),
      loading: () {},
    );
  }

  void edit(AiRasterDraft draft) =>
      state = state.copyWith(draft: draft, error: null);
  void raw(String value) {
    final lines = rasterSourceLines(value);
    edit(
      state.draft.copyWith(
        rawWod: value,
        groups: lines.isEmpty
            ? []
            : [AiRasterGroup(heading: 'A', lines: lines)],
      ),
    );
  }

  void heading(int index, String value) => edit(
    state.draft.copyWith(
      groups: [
        for (final (i, group) in state.draft.groups.indexed)
          i == index ? group.copyWith(heading: value) : group,
      ],
    ),
  );
  void groupCount(int count) {
    final lines = rasterSourceLines(state.draft.rawWod);
    if (count < 1 || count > 3 || lines.length < count) return;
    edit(
      state.draft.copyWith(
        groups: [
          for (var i = 0; i < count; i++)
            AiRasterGroup(
              heading: String.fromCharCode(65 + i),
              lines: lines.sublist(
                (i * lines.length / count).floor(),
                ((i + 1) * lines.length / count).floor(),
              ),
            ),
        ],
      ),
    );
  }

  void applyRequestedSettings() {
    final brief = state.draft.brief;
    final requested = RegExp(r'(?:([123])|([한두세]))\s*(?:개\s*)?(?:그룹|단|열)')
        .firstMatch(brief);
    if (requested != null) {
      groupCount(
        int.tryParse(requested.group(1) ?? '') ??
            {'한': 1, '두': 2, '세': 3}[requested.group(2)]!,
      );
    }
    if (RegExp(
      r'글[자씨].{0,8}(?:작|줄)|작은\s*글[자씨]|smaller',
      caseSensitive: false,
    ).hasMatch(brief)) {
      edit(state.draft.copyWith(bodyFontSize: 32));
    }
  }

  void split(int index, int after) {
    final groups = state.draft.groups;
    if (groups.length >= 3 ||
        after < 1 ||
        after >= groups[index].lines.length) {
      return;
    }
    edit(
      state.draft.copyWith(
        groups: [
          ...groups.take(index),
          groups[index].copyWith(
            lines: groups[index].lines.take(after).toList(),
          ),
          AiRasterGroup(
            heading: String.fromCharCode(65 + index + 1),
            lines: groups[index].lines.skip(after).toList(),
          ),
          ...groups.skip(index + 1),
        ],
      ),
    );
  }

  void merge(int index) {
    final groups = state.draft.groups;
    if (index < 1 || index >= groups.length) return;
    edit(
      state.draft.copyWith(
        groups: [
          ...groups.take(index - 1),
          groups[index - 1].copyWith(
            lines: [...groups[index - 1].lines, ...groups[index].lines],
          ),
          ...groups.skip(index + 1),
        ],
      ),
    );
  }

  Future<void> organize() async {
    if (state.busy) return;
    final draft = state.draft, lifetime = _lifetime;
    state = state.copyWith(busy: true, error: null);
    final result = await AsyncValue.guard(() => _actions.organize(draft));
    if (!_current(lifetime)) return;
    result.when(
      data: (value) {
        state = state.copyWith(
          busy: false,
          remaining: value.remaining,
          limit: value.limit,
          draft: state.draft == draft
              ? draft.copyWith(groups: value.groups)
              : state.draft,
        );
      },
      error: (error, _) => _error(error),
      loading: () {},
    );
  }

  void _accept(AiRasterReply reply) {
    final job = reply.job;
    if (job.brandKey != state.brand?.key) {
      _error(
        const AiSlidesFailure('센터 참고 이미지가 변경되었어요.', reason: 'brand-stale'),
      );
      return;
    }
    final completed = job.status == 'completed';
    final pending = ['processing', 'uncertain'].contains(job.status);
    state = state.copyWith(
      busy: false,
      remaining: reply.remaining,
      limit: reply.limit,
      result: completed ? job : state.result,
      history:
          completed &&
              state.result != null &&
              state.result!.requestId != job.requestId
          ? [state.result!, ...state.history].take(3).toList()
          : state.history,
      pendingRequestId: pending ? job.requestId : null,
      pendingStatus: job.status,
      error: job.message,
    );
  }

  Future<void> generate() async {
    if (state.busy || state.pendingRequestId != null || state.brand == null) {
      return;
    }
    final validation = rasterDraftError(state.draft);
    if (validation != null) {
      _error(AiSlidesFailure(validation, code: 'invalid-argument'));
      return;
    }
    final lifetime = _lifetime, requestId = newId();
    final draft = state.draft,
        brand = state.brand!,
        previous = state.result?.requestId;
    state = state.copyWith(
      busy: true,
      pendingRequestId: requestId,
      pendingStatus: 'processing',
      error: null,
    );
    final result = await AsyncValue.guard(
      () => _actions.generate(draft, brand, requestId, previous),
    );
    if (!_current(lifetime)) return;
    result.when(
      data: _accept,
      error: (error, _) {
        // Transport uncertainty retains the same ID; retry is status-only.
        _error(error);
        state = state.copyWith(pendingStatus: 'uncertain');
        if (error is AiSlidesFailure &&
            [
              'invalid-argument',
              'failed-precondition',
              'resource-exhausted',
              'permission-denied',
            ].contains(error.code)) {
          state = state.copyWith(pendingRequestId: null);
        }
      },
      loading: () {},
    );
  }

  Future<void> refreshResult() async {
    final requestId = state.pendingRequestId;
    if (state.busy || requestId == null) return;
    final lifetime = _lifetime;
    state = state.copyWith(busy: true, error: null);
    final result = await AsyncValue.guard(() => _actions.status(requestId));
    if (!_current(lifetime)) return;
    result.when(
      data: _accept,
      error: (error, _) => _error(error),
      loading: () {},
    );
  }

  void newRequest() {
    if (state.busy) return;
    state = state.copyWith(
      pendingRequestId: null,
      pendingStatus: null,
      error: null,
    );
  }

  void undo() {
    if (state.busy || state.history.isEmpty) return;
    final previous = state.history.first;
    state = state.copyWith(
      result: previous,
      draft: previous.draft,
      history: state.history.skip(1).toList(),
      error: null,
    );
  }

  Future<WorkoutModule?> add() async {
    if (state.busy || state.result == null || state.brand == null) return null;
    final lifetime = _lifetime;
    state = state.copyWith(busy: true, error: null);
    final result = await AsyncValue.guard(
      () => _actions.add(state.result!, state.brand!),
    );
    if (!_current(lifetime)) return null;
    state = state.copyWith(busy: false);
    if (result.hasError) {
      _error(result.error!);
      return null;
    }
    return result.value;
  }
}
