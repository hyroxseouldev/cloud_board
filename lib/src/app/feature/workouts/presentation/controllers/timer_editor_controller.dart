import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

part 'timer_editor_controller.g.dart';
part 'timer_editor_controller.freezed.dart';

@freezed
abstract class TimerEditorState with _$TimerEditorState {
  const TimerEditorState._();
  const factory TimerEditorState({
    required WorkoutModule module,
    required WorkoutTimerMode inputMode,
    @Default(false) bool detailed,
    @Default({}) Map<String, String> errors,
    @Default(0) int formRevision,
    @Default(600) int lastTimeCap,
  }) = _TimerEditorState;

  bool get valid => errors.isEmpty && timingValidationError(module) == null;
}

@riverpod
class TimerEditorController extends _$TimerEditorController {
  @override
  TimerEditorState build(WorkoutModule initial) => TimerEditorState(
    module: initial,
    inputMode: timerInputMode(initial),
    detailed: timerInputMode(initial) == WorkoutTimerMode.custom,
    lastTimeCap: initial.workSeconds > 0 ? initial.workSeconds : 600,
  );

  bool get dirty =>
      state.errors.isNotEmpty || !sameSlideTiming(initial, state.module);

  void replace(WorkoutModule module) {
    state = state.copyWith(
      module: copySlideTiming(state.module, module),
      inputMode: timerInputMode(module),
      detailed: timerInputMode(module) == WorkoutTimerMode.custom,
      errors: {},
      formRevision: state.formRevision + 1,
      lastTimeCap: module.workSeconds > 0 ? module.workSeconds : 600,
    );
  }

  void showDetails(bool value) {
    if (!state.valid) return;
    if (!value && timerInputMode(state.module) == WorkoutTimerMode.custom) {
      return;
    }
    state = state.copyWith(
      detailed: value,
      inputMode: timerInputMode(state.module),
    );
  }

  void _update(WorkoutModule next) {
    state = state.copyWith(module: next);
  }

  void setInput(String field, String raw, {String? blockId}) {
    final key = blockId == null ? field : '$blockId-$field';
    final count = ['repeats', 'rounds', 'intervals'].contains(field);
    final match = RegExp(r'^(\d{1,3}):([0-5]\d)$').firstMatch(raw.trim());
    final value = count
        ? int.tryParse(raw)
        : match == null
        ? null
        : int.parse(match[1]!) * 60 + int.parse(match[2]!);
    final min =
        count ||
            (field == 'work' && isContinuousTimer(state.module)) ||
            field == 'interval'
        ? 1
        : 0;
    final max = field == 'intervals'
        ? maxTimingBlocks
        : count
        ? maxTimingRepeats
        : maxTimingSeconds;
    final errors = {...state.errors};
    if (value == null || value < min || value > max) {
      errors[key] = count
          ? '$min~$max 사이로 입력해 주세요.'
          : '${min == 0 ? '00:00' : '00:01'}~999:59로 입력해 주세요.';
      state = state.copyWith(errors: errors);
      return;
    }
    errors.remove(key);
    state = state.copyWith(errors: errors);
    final m = state.module;
    if (blockId != null) {
      final blocks = effectiveIntervalBlocks(m);
      final existing = blocks.where((b) => b.id == blockId).firstOrNull;
      if (existing == null ||
          (field == 'work' && existing.workSeconds == value) ||
          (field == 'rest' && existing.restSeconds == value) ||
          (field == 'repeats' && existing.sets == value)) {
        return;
      }
      _update(
        editTimerBlocks(m, [
          for (final b in blocks)
            if (b.id != blockId)
              b
            else
              b.copyWith(
                workSeconds: field == 'work' ? value : b.workSeconds,
                restSeconds: field == 'rest' ? value : b.restSeconds,
                sets: field == 'repeats' ? value : b.sets,
              ),
        ]),
      );
    } else if (isContinuousTimer(m)) {
      if (value == m.workSeconds) return;
      _update(m.copyWith(workSeconds: value));
      state = state.copyWith(lastTimeCap: value);
    } else if (state.inputMode == WorkoutTimerMode.emom && !state.detailed) {
      final blocks = effectiveIntervalBlocks(m);
      if ((field == 'interval' && blocks.first.workSeconds == value) ||
          (field == 'intervals' && blocks.length == value) ||
          (field == 'rounds' && m.rounds == value) ||
          (field == 'roundRest' && m.roundRestSeconds == value)) {
        return;
      }
      _update(
        editEmom(m, (
          seconds: field == 'interval' ? value : blocks.first.workSeconds,
          intervals: field == 'intervals' ? value : blocks.length,
          rounds: field == 'rounds' ? value : m.rounds,
          restSeconds: field == 'roundRest' ? value : m.roundRestSeconds,
          includeFinalRest: m.includeFinalRoundRest,
        )),
      );
    } else if (field == 'rounds' || field == 'roundRest') {
      final next = m.copyWith(
        rounds: field == 'rounds' ? value : m.rounds,
        roundRestSeconds: field == 'roundRest' ? value : m.roundRestSeconds,
      );
      if (sameSlideTiming(m, next)) return;
      _update(editTimerBlocks(next, effectiveIntervalBlocks(next)));
    } else {
      final b = effectiveIntervalBlocks(m).first;
      final next = b.copyWith(
        workSeconds: field == 'work' ? value : b.workSeconds,
        restSeconds: field == 'rest' ? value : b.restSeconds,
        sets: field == 'repeats' ? value : b.sets,
      );
      if (b == next) return;
      _update(editTimerBlocks(m, [next]));
    }
  }

  void setFinalRest(bool value, {bool round = false}) {
    final m = state.module;
    final next = round
        ? m.copyWith(includeFinalRoundRest: value)
        : m.copyWith(includeFinalRest: value);
    if (m == next) return;
    _update(editTimerBlocks(next, effectiveIntervalBlocks(next)));
  }

  void setCapped(bool value) {
    final errors = {...state.errors}..remove('work');
    state = state.copyWith(
      errors: errors,
      module: state.module.copyWith(
        workSeconds: value ? state.lastTimeCap : 0,
        timerDirection: value ? state.module.timerDirection : TimerDirection.up,
      ),
      formRevision: state.formRevision + 1,
    );
  }

  void setDirection(TimerDirection value) =>
      _update(state.module.copyWith(timerDirection: value));

  void addBlock({required bool restOnly}) {
    final blocks = effectiveIntervalBlocks(state.module);
    if (blocks.length >= maxTimingBlocks) return;
    _update(
      editTimerBlocks(state.module, [
        ...blocks,
        WorkoutIntervalBlock(
          id: newId(),
          workSeconds: restOnly ? 0 : 60,
          restSeconds: restOnly ? 30 : 0,
          sets: 1,
        ),
      ]),
    );
  }

  void blockAction(String id, String action) {
    final blocks = [...effectiveIntervalBlocks(state.module)];
    final i = blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    switch (action) {
      case 'up':
        if (i > 0) blocks.insert(i - 1, blocks.removeAt(i));
      case 'down':
        if (i < blocks.length - 1) blocks.insert(i + 1, blocks.removeAt(i));
      case 'duplicate':
        if (blocks.length < maxTimingBlocks) {
          blocks.insert(i + 1, blocks[i].copyWith(id: newId()));
        }
      case 'type':
        final restOnly = blocks[i].workSeconds == 0;
        blocks[i] = blocks[i].copyWith(
          workSeconds: restOnly ? 60 : 0,
          restSeconds: blocks[i].restSeconds > 0 ? blocks[i].restSeconds : 30,
        );
      case 'delete':
        if (blocks.length > 1) blocks.removeAt(i);
    }
    final errors = {...state.errors}
      ..removeWhere(
        (k, _) =>
            k.startsWith('$id-') &&
            (!blocks.any((b) => b.id == id) || action == 'type'),
      );
    state = state.copyWith(
      errors: errors,
      formRevision: state.formRevision + (action == 'type' ? 1 : 0),
    );
    _update(editTimerBlocks(state.module, blocks));
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final blocks = [...effectiveIntervalBlocks(state.module)];
    blocks.insert(newIndex, blocks.removeAt(oldIndex));
    _update(editTimerBlocks(state.module, blocks));
  }
}
