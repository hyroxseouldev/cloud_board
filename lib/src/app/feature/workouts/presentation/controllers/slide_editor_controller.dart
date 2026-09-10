import 'dart:async';
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
part 'slide_editor_controller.g.dart';
part 'slide_editor_controller.freezed.dart';

@freezed
abstract class SlideEditorState with _$SlideEditorState {
  const SlideEditorState._();
  const factory SlideEditorState({
    required WorkoutModule module,
    required WorkoutModule saved,
    @Default([]) List<WorkoutModule> undo,
    @Default([]) List<WorkoutModule> redo,
    @Default([]) List<WorkoutModule> styles,
    WorkoutModule? recovery,
    @Default(false) bool localSaved,
    String? storageError,
  }) = _SlideEditorState;
  bool get dirty => module != saved;
}

@riverpod
class SlideEditorController extends _$SlideEditorController {
  Timer? _debounce;
  bool _loaded = false;
  bool _savedDuringLoad = false;
  String? _group;
  DateTime? _lastChange;
  late SlideEditorActions _actions;
  late String _key;
  @override
  SlideEditorState build(
    String workoutId,
    WorkoutModule original,
    String scope,
  ) {
    _actions = ref.watch(slideEditorActionsProvider);
    _key = base64Url.encode(utf8.encode('$scope/$workoutId/${original.id}'));
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(_load);
    return SlideEditorState(module: original, saved: original);
  }

  Future<void> _load() async {
    try {
      final draft = await _actions.loadDraft(_key);
      final styles = await _actions.loadStyles(scope);
      if (!ref.mounted) return;
      state = state.copyWith(
        recovery: !_savedDuringLoad && draft != null && draft != state.saved
            ? draft
            : null,
        styles: styles,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          storageError: '이 기기의 임시저장을 사용할 수 없습니다. 저장 버튼으로 저장해 주세요.',
        );
      }
    } finally {
      _loaded = true;
      if (ref.mounted && state.dirty) _schedule();
    }
  }

  void update(WorkoutModule next, {String? group}) {
    if (next == state.module) return;
    final now = DateTime.now();
    final merge =
        group != null &&
        group == _group &&
        _lastChange != null &&
        now.difference(_lastChange!).inMilliseconds < 600;
    state = state.copyWith(
      module: next,
      undo: merge
          ? state.undo
          : [
              ...state.undo,
              state.module,
            ].reversed.take(50).toList().reversed.toList(),
      redo: [],
      localSaved: false,
    );
    _group = group;
    _lastChange = now;
    _schedule();
  }

  void undo() {
    if (state.undo.isEmpty) return;
    state = state.copyWith(
      module: state.undo.last,
      undo: state.undo.sublist(0, state.undo.length - 1),
      redo: [...state.redo, state.module],
      localSaved: false,
    );
    _group = null;
    _schedule();
  }

  void redo() {
    if (state.redo.isEmpty) return;
    state = state.copyWith(
      module: state.redo.last,
      redo: state.redo.sublist(0, state.redo.length - 1),
      undo: [...state.undo, state.module],
      localSaved: false,
    );
    _group = null;
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(flush()),
    );
  }

  Future<void> flush() async {
    _debounce?.cancel();
    final snapshot = state.module;
    final dirty = state.dirty;
    // A lifecycle flush must not discard a draft awaiting a recovery decision.
    if (!_loaded || (!dirty && state.recovery != null)) return;
    try {
      if (dirty) {
        await _actions.saveDraft(_key, snapshot);
      } else {
        await _actions.clearDraft(_key);
      }
      if (ref.mounted && state.module == snapshot) {
        state = state.copyWith(localSaved: dirty, storageError: null);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(storageError: '임시저장에 실패했습니다. 저장 버튼으로 저장해 주세요.');
      }
    }
  }

  void restore() {
    final recovered = state.recovery;
    if (recovered == null) return;
    update(recovered.copyWith(id: state.module.id));
    state = state.copyWith(recovery: null);
  }

  Future<void> dismissRecovery() async {
    state = state.copyWith(recovery: null);
    await flush();
  }

  Future<void> markSaved(WorkoutModule saved) async {
    _debounce?.cancel();
    _savedDuringLoad = true;
    state = state.copyWith(
      module: saved,
      saved: saved,
      localSaved: false,
      recovery: null,
    );
    try {
      await _actions.clearDraft(_key);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          storageError: '저장은 완료했지만 이 기기의 이전 임시저장을 지우지 못했습니다.',
        );
      }
    }
  }

  Future<void> discard() async {
    _debounce?.cancel();
    await _actions.clearDraft(_key);
  }

  Future<void> saveStyle(String name) async {
    final style = applySlideStyle(
      WorkoutModule.empty(newId()),
      state.module,
    ).copyWith(name: name.trim());
    final styles = [
      ...state.styles.where((value) => value.name != style.name),
      style,
    ];
    await _actions.saveStyles(scope, styles);
    if (ref.mounted) state = state.copyWith(styles: styles);
  }

  Future<void> deleteStyle(String id) async {
    final styles = state.styles.where((value) => value.id != id).toList();
    await _actions.saveStyles(scope, styles);
    if (ref.mounted) state = state.copyWith(styles: styles);
  }
}
