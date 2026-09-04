import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/workout.dart';

part 'player_controller.freezed.dart';
part 'player_controller.g.dart';

@freezed
abstract class PlayerStep with _$PlayerStep {
  const factory PlayerStep({
    required WorkoutModule module,
    required int moduleIndex,
    required int set,
    required int totalSets,
    required int duration,
    required bool isRest,
  }) = _PlayerStep;
}

@freezed
abstract class PlayerState with _$PlayerState {
  const factory PlayerState({
    required List<PlayerStep> steps,
    required int index,
    required int secondsLeft,
    required bool isPaused,
  }) = _PlayerState;
}

@riverpod
class PlayerController extends _$PlayerController {
  Timer? _ticker;
  DateTime? _endsAt;

  @override
  PlayerState build(Workout workout, {int startModule = 0}) {
    final steps = <PlayerStep>[];
    for (var index = 0; index < workout.modules.length; index++) {
      final module = workout.modules[index];
      for (var set = 1; set <= max(1, module.sets); set++) {
        steps.add(
          PlayerStep(
            module: module,
            moduleIndex: index,
            set: set,
            totalSets: max(1, module.sets),
            duration: max(1, module.workSeconds),
            isRest: false,
          ),
        );
        if (set < module.sets && module.restSeconds > 0) {
          steps.add(
            PlayerStep(
              module: module,
              moduleIndex: index,
              set: set,
              totalSets: module.sets,
              duration: module.restSeconds,
              isRest: true,
            ),
          );
        }
      }
    }
    final initialIndex = steps
        .indexWhere((step) => step.moduleIndex == startModule)
        .clamp(0, max(0, steps.length - 1))
        .toInt();
    final initial = PlayerState(
      steps: steps,
      index: initialIndex,
      secondsLeft: steps.isEmpty ? 0 : steps[initialIndex].duration,
      isPaused: false,
    );
    _endsAt = DateTime.now().add(Duration(seconds: initial.secondsLeft));
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    ref.onDispose(() => _ticker?.cancel());
    return initial;
  }

  PlayerStep? get currentStep =>
      state.steps.isEmpty ? null : state.steps[state.index];

  void _tick() {
    if (state.isPaused || _endsAt == null || currentStep == null) return;
    final left = max(
      0,
      _endsAt!.difference(DateTime.now()).inMilliseconds / 1000,
    ).ceil();
    if (left != state.secondsLeft) {
      state = state.copyWith(secondsLeft: left);
      final step = currentStep!;
      if (step.module.beep && left > 0 && left <= 3) {
        SystemSound.play(SystemSoundType.click);
      }
    }
    if (left <= 0) {
      next();
    }
  }

  void toggle() {
    if (state.isPaused) {
      _endsAt = DateTime.now().add(Duration(seconds: state.secondsLeft));
      state = state.copyWith(isPaused: false);
    } else {
      state = state.copyWith(isPaused: true);
    }
  }

  void next() => _go(state.index + 1);
  void previous() => _go(
    state.secondsLeft < (currentStep?.duration ?? 0) - 3
        ? state.index
        : state.index - 1,
  );

  void _go(int index) {
    if (index >= state.steps.length) {
      _ticker?.cancel();
      state = state.copyWith(index: state.steps.length, secondsLeft: 0);
      return;
    }
    final safeIndex = max(0, index);
    final step = state.steps[safeIndex];
    _endsAt = DateTime.now().add(Duration(seconds: step.duration));
    state = state.copyWith(
      index: safeIndex,
      secondsLeft: step.duration,
      isPaused: false,
    );
    if (step.module.beep) SystemSound.play(SystemSoundType.click);
  }
}
