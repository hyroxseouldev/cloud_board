import 'dart:async';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';

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
    required int remainingMs,
    required bool isPaused,
    @Default(false) bool briefing,
    @Default(0) int countdownMs,
  }) = _PlayerState;
}

extension PlayerStateTime on PlayerState {
  int get secondsLeft => (remainingMs / 1000).ceil();
}

List<PlayerStep> buildPlayerSteps(Workout workout) {
  final steps = <PlayerStep>[];
  for (var index = 0; index < workout.modules.length; index++) {
    final module = workout.modules[index];
    for (final block in effectiveIntervalBlocks(module)) {
      for (var set = 1; set <= max(1, block.sets); set++) {
        steps.add(
          PlayerStep(
            module: module,
            moduleIndex: index,
            set: set,
            totalSets: max(1, block.sets),
            duration: max(1, block.workSeconds),
            isRest: false,
          ),
        );
        if (set < block.sets && block.restSeconds > 0) {
          steps.add(
            PlayerStep(
              module: module,
              moduleIndex: index,
              set: set,
              totalSets: block.sets,
              duration: block.restSeconds,
              isRest: true,
            ),
          );
        }
      }
    }
  }
  return steps;
}

int playerStepIndexForModule(Workout workout, int moduleIndex) {
  final steps = buildPlayerSteps(workout);
  return steps
      .indexWhere((step) => step.moduleIndex == moduleIndex)
      .clamp(0, max(0, steps.length - 1));
}

int synchronizedRemainingMs({
  required PlaybackSession session,
  required int localNowMs,
  required int serverTimeOffsetMs,
}) {
  if (session.status != PlaybackStatus.playing) return session.remainingMs;
  final serverNow = localNowMs + serverTimeOffsetMs;
  return (session.remainingMs -
          max<int>(
            0,
            serverNow - session.anchorServerMs - session.startDelayMs,
          ))
      .clamp(0, session.remainingMs);
}

/// Resolve elapsed steps too, so a reconnect does not restart an old slide.
({int index, int remainingMs, int countdownMs}) resolvePlaybackPosition(
  PlaybackSession session,
  List<PlayerStep> steps,
  int serverNowMs,
) {
  var index = session.stepIndex.clamp(0, steps.length);
  if (session.status == PlaybackStatus.completed) {
    return (index: steps.length, remainingMs: 0, countdownMs: 0);
  }
  if (session.status != PlaybackStatus.playing || session.briefing) {
    return (index: index, remainingMs: session.remainingMs, countdownMs: 0);
  }
  final elapsed = max<int>(0, serverNowMs - session.anchorServerMs);
  final countdown = max<int>(0, session.startDelayMs - elapsed);
  var remaining =
      session.remainingMs - max<int>(0, elapsed - session.startDelayMs);
  while (remaining <= 0 && index < steps.length) {
    index++;
    if (index < steps.length) remaining += steps[index].duration * 1000;
  }
  return (index: index, remainingMs: max(0, remaining), countdownMs: countdown);
}

@riverpod
class PlayerController extends _$PlayerController {
  Timer? _ticker;
  DateTime? _endsAt;
  DateTime? _startsAt;
  bool _transitioning = false;
  String? _announcedSessionId;
  int? _announcedStepIndex;
  bool _announcedCompletion = false;

  @override
  PlayerState build(
    Workout workout, {
    int startModule = 0,
    String? sessionId,
    bool canControl = true,
  }) {
    _ticker?.cancel();
    final steps = buildPlayerSteps(workout);
    final remote = sessionId == null
        ? null
        : ref.watch(activePlaybackSessionProvider).value;
    final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;
    final matchesSession = remote != null && remote.id == sessionId;

    late final int index;
    late final int remainingMs;
    late final bool isPaused;
    var countdownMs = 0;
    if (matchesSession) {
      if (remote.status == PlaybackStatus.completed) {
        index = steps.length;
        isPaused = true;
        remainingMs = 0;
      } else {
        final position = resolvePlaybackPosition(
          remote,
          steps,
          DateTime.now().millisecondsSinceEpoch + offset,
        );
        index = position.index;
        isPaused = remote.status != PlaybackStatus.playing;
        remainingMs = position.remainingMs;
        countdownMs = position.countdownMs;
      }
    } else {
      index = playerStepIndexForModule(workout, startModule);
      remainingMs = steps.isEmpty ? 0 : steps[index].duration * 1000;
      isPaused = false;
    }

    final initial = PlayerState(
      steps: steps,
      index: index,
      remainingMs: remainingMs,
      isPaused: isPaused,
      briefing: matchesSession && remote.briefing,
      countdownMs: countdownMs,
    );
    _setDeadline(initial);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    Future.microtask(() {
      if (!ref.mounted) return;
      if (index >= steps.length) {
        _announceCompletion();
      } else if (initial.countdownMs > 0 && steps[index].module.beep) {
        _play(workout.countdownSound);
      } else if (!initial.briefing &&
          initial.countdownMs == 0 &&
          !initial.isPaused) {
        _announceStep(index);
      }
    });
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return initial;
  }

  PlayerStep? get currentStep =>
      state.steps.isEmpty || state.index >= state.steps.length
      ? null
      : state.steps[state.index];

  void _setDeadline(PlayerState value) {
    _startsAt = value.countdownMs > 0
        ? DateTime.now().add(Duration(milliseconds: value.countdownMs))
        : null;
    _endsAt = value.isPaused
        ? null
        : DateTime.now().add(
            Duration(milliseconds: value.remainingMs + value.countdownMs),
          );
  }

  void _tick() {
    if (state.isPaused || _endsAt == null || currentStep == null) return;
    if (_startsAt != null) {
      final countdown = max(
        0,
        _startsAt!.difference(DateTime.now()).inMilliseconds,
      );
      final previousSecond = (state.countdownMs / 1000).ceil();
      state = state.copyWith(countdownMs: countdown);
      if (countdown > 0) {
        if ((countdown / 1000).ceil() != previousSecond &&
            currentStep!.module.beep) {
          _play(workout.countdownSound);
        }
        return;
      }
      _startsAt = null;
      _announceStep(state.index);
    }
    final left = max(0, _endsAt!.difference(DateTime.now()).inMilliseconds);
    final previousSecond = state.secondsLeft;
    if (left != state.remainingMs) {
      state = state.copyWith(remainingMs: left);
      final second = state.secondsLeft;
      if (currentStep!.module.beep &&
          second > 0 &&
          second <= 3 &&
          second != previousSecond) {
        _play(workout.countdownSound);
      }
    }
    if (left <= 0 && !_transitioning) {
      var nextIndex = state.index + 1;
      var nextRemaining = _endsAt!.difference(DateTime.now()).inMilliseconds;
      while (nextIndex < state.steps.length) {
        nextRemaining += state.steps[nextIndex].duration * 1000;
        if (nextRemaining > 0) break;
        nextIndex++;
      }
      final isFinalStep = nextIndex >= state.steps.length;
      if (isFinalStep) {
        _endsAt = null;
        state = state.copyWith(
          index: state.steps.length,
          remainingMs: 0,
          isPaused: true,
        );
        _announceCompletion();
        if (canControl && sessionId != null) {
          unawaited(
            ref.read(playbackActionControllerProvider.notifier).syncComplete(),
          );
        }
        return;
      }
      if (canControl && sessionId != null) {
        unawaited(
          _seekRemote(nextIndex, silent: true, remainingMs: nextRemaining),
        );
      } else {
        _goLocal(nextIndex, remainingMs: nextRemaining);
      }
    }
  }

  Future<void> toggle() async {
    if (!canControl || state.briefing || state.countdownMs > 0) return;
    if (sessionId == null) {
      _toggleLocal();
      return;
    }
    final previous = state;
    if (state.isPaused) {
      _setDeadline(state.copyWith(isPaused: false));
      state = state.copyWith(isPaused: false);
      final success = await ref
          .read(playbackActionControllerProvider.notifier)
          .resume();
      if (!success) {
        state = previous;
        _setDeadline(previous);
      }
    } else {
      state = state.copyWith(isPaused: true);
      _endsAt = null;
      final success = await ref
          .read(playbackActionControllerProvider.notifier)
          .pause(state.remainingMs);
      if (!success) {
        state = previous;
        _setDeadline(previous);
      }
    }
  }

  Future<void> play() async {
    if (state.isPaused && currentStep != null) await toggle();
  }

  Future<void> pause() async {
    if (!state.isPaused && currentStep != null) await toggle();
  }

  Future<void> next() async {
    if (!canControl || state.briefing || state.countdownMs > 0) return;
    if (sessionId == null || !canControl) {
      _goLocal(state.index + 1);
      return;
    }
    await _seekRemote(state.index + 1);
  }

  Future<void> previous() async {
    if (!canControl || state.briefing || state.countdownMs > 0) return;
    final target =
        state.remainingMs < (currentStep?.duration ?? 0) * 1000 - 3000
        ? state.index
        : state.index - 1;
    if (sessionId == null || !canControl) {
      _goLocal(target);
      return;
    }
    await _seekRemote(target);
  }

  void _toggleLocal() {
    if (state.isPaused) {
      _setDeadline(state.copyWith(isPaused: false));
      state = state.copyWith(isPaused: false);
    } else {
      state = state.copyWith(isPaused: true);
      _endsAt = null;
    }
  }

  Future<void> _seekRemote(
    int index, {
    bool silent = false,
    int? remainingMs,
  }) async {
    if (_transitioning) return;
    _transitioning = true;
    try {
      if (index >= state.steps.length) {
        _ticker?.cancel();
        state = state.copyWith(index: state.steps.length, remainingMs: 0);
        if (silent) {
          await ref
              .read(playbackActionControllerProvider.notifier)
              .syncComplete();
        } else {
          await ref.read(playbackActionControllerProvider.notifier).complete();
        }
        return;
      }
      final safeIndex = max(0, index);
      final previous = state;
      _goLocal(safeIndex, remainingMs: remainingMs);
      final notifier = ref.read(playbackActionControllerProvider.notifier);
      final success = silent
          ? await notifier.syncStep(
              stepIndex: safeIndex,
              durationMs: state.remainingMs,
            )
          : await notifier.seek(
              stepIndex: safeIndex,
              durationMs: state.steps[safeIndex].duration * 1000,
            );
      if (!success) {
        state = previous;
        _setDeadline(previous);
      }
    } finally {
      _transitioning = false;
    }
  }

  void _goLocal(int index, {int? remainingMs}) {
    if (index >= state.steps.length) {
      _ticker?.cancel();
      state = state.copyWith(index: state.steps.length, remainingMs: 0);
      return;
    }
    final safeIndex = max(0, index);
    final next = state.copyWith(
      index: safeIndex,
      remainingMs: remainingMs ?? state.steps[safeIndex].duration * 1000,
      isPaused: false,
    );
    state = next;
    _setDeadline(next);
    _announcedStepIndex = null;
    _announceStep(safeIndex);
  }

  void _announceStep(int index) {
    if (index < 0 || index >= state.steps.length) return;
    if (_announcedSessionId == sessionId && _announcedStepIndex == index) {
      return;
    }
    _announcedSessionId = sessionId;
    _announcedStepIndex = index;
    _announcedCompletion = false;
    final step = state.steps[index];
    if (!step.module.beep) return;
    _play(step.isRest ? workout.restStartSound : workout.workStartSound);
  }

  void _announceCompletion() {
    if (_announcedCompletion) return;
    _announcedCompletion = true;
    _announcedStepIndex = state.steps.length;
    if (state.steps.isNotEmpty && state.steps.last.module.beep) {
      _play(workout.workoutEndSound);
    }
  }

  void _play(WorkoutSound sound) {
    unawaited(
      ref
          .read(beepPlayerProvider)
          .play(sound, workout.soundVolume)
          .catchError((_) {}),
    );
  }
}
