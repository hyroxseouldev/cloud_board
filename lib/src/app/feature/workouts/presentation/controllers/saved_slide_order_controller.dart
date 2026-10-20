import 'dart:async';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/saved_slide_order.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/saved_slide_order_actions.dart';

part 'saved_slide_order_controller.g.dart';
part 'saved_slide_order_controller.freezed.dart';

@freezed
abstract class SavedSlideOrderState with _$SavedSlideOrderState {
  const factory SavedSlideOrderState({
    @Default([]) List<String> ids,
    @Default(false) bool ready,
    @Default(false) bool saving,
    String? error,
  }) = _SavedSlideOrderState;
}

@riverpod
class SavedSlideOrderController extends _$SavedSlideOrderController {
  List<String> _remote = [];
  List<String> _known = [];
  String? _lastSynchronization;
  SavedSlideMove? _retryMove;
  late SavedSlideOrderActions _actions;

  @override
  SavedSlideOrderState build(String scope) {
    _actions = ref.watch(savedSlideOrderActionsProvider);
    final subscription = _actions
        .watch(scope)
        .listen(
          (ids) {
            _remote = ids;
            if (ref.mounted && !state.saving) {
              state = state.copyWith(ids: ids, ready: true);
            }
          },
          onError: (Object error) {
            if (ref.mounted) {
              state = state.copyWith(error: '칩 순서를 불러오지 못했습니다. 다시 시도해 주세요.');
            }
          },
        );
    ref.onDispose(subscription.cancel);
    return const SavedSlideOrderState();
  }

  Future<void> synchronize(List<String> liveIds) async {
    _known = liveIds;
    if (!state.ready || state.saving || state.error != null) return;
    final next = reconcileSavedSlideOrder(state.ids, liveIds);
    if (!const ListEquality<String>().equals(state.ids, next)) {
      // The library and profile are independent streams. A delayed library
      // snapshot can omit a still-live ID which the transaction must preserve.
      // Do not retry that same pair on every saving/ids notification.
      final sortedLive = liveIds.toSet().toList()..sort();
      final inputs = '${sortedLive.join(",")}|${state.ids.join(",")}';
      if (_lastSynchronization == inputs) return;
      _lastSynchronization = inputs;
      await _write();
    } else {
      _lastSynchronization = null;
    }
  }

  Future<void> move(List<String> ids, int oldIndex, int newIndex) async {
    if (!state.ready || state.saving || oldIndex == newIndex) return;
    if (oldIndex < 0 ||
        oldIndex >= ids.length ||
        newIndex < 0 ||
        newIndex >= ids.length) {
      return;
    }
    _known = ids;
    final next = [...ids];
    final id = next.removeAt(oldIndex);
    next.insert(newIndex, id);
    await _write(
      move: (
        id: id,
        beforeId: newIndex + 1 < next.length ? next[newIndex + 1] : null,
        afterId: newIndex > 0 ? next[newIndex - 1] : null,
      ),
    );
  }

  Future<void> retry() async {
    if (state.saving) return;
    if (!state.ready) {
      final result = await AsyncValue.guard(() => _actions.load(scope));
      if (!ref.mounted) return;
      if (result.hasError) return;
      _remote = result.requireValue;
      state = state.copyWith(ids: _remote, ready: true, error: null);
    }
    await _write(move: _retryMove);
  }

  Future<void> _write({SavedSlideMove? move}) async {
    _retryMove = move;
    state = state.copyWith(
      ids: reconcileSavedSlideOrder(state.ids, _known, move: move),
      saving: true,
      error: null,
    );
    final result = await AsyncValue.guard(() async {
      await _actions.reconcile(scope, _known, move: move);
      // Include a later device commit that arrived while this write completed.
      return _actions.load(scope);
    });
    if (!ref.mounted) return;
    if (result.hasError) {
      state = state.copyWith(
        ids: _remote,
        saving: false,
        error: '칩 순서 저장을 확인하지 못했습니다. 다시 시도해 주세요.',
      );
    } else {
      _retryMove = null;
      _remote = result.requireValue;
      state = state.copyWith(ids: _remote, saving: false, error: null);
    }
  }
}
