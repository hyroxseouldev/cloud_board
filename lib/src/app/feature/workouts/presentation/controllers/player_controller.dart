import 'dart:async';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/beep_player.dart';
import '../../../playback/domain/entities/playback_session.dart';
import '../../../playback/presentation/controllers/playback_session_controller.dart';
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
    required int remainingMs,
    required bool isPaused,
  }) = _PlayerState;
}

extension PlayerStateTime on PlayerState {
  int get secondsLeft => (remainingMs / 1000).ceil();
}

List<PlayerStep> buildPlayerSteps(Workout workout) {
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
  return max(0, session.remainingMs - (serverNow - session.anchorServerMs));
}

@riverpod
class PlayerController extends _$PlayerController {
  Timer? _ticker;
  DateTime? _endsAt;
  bool _transitioning = false;

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
    if (matchesSession) {
      if (remote.status == PlaybackStatus.completed) {
        index = steps.length;
        isPaused = true;
        remainingMs = 0;
      } else {
        index = remote.stepIndex.clamp(0, steps.length);
        isPaused = remote.status != PlaybackStatus.playing;
        remainingMs = _remainingFromRemote(remote, offset);
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
    );
    _setDeadline(initial);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return initial;
  }

  PlayerStep? get currentStep =>
      state.steps.isEmpty || state.index >= state.steps.length
      ? null
      : state.steps[state.index];

  int _remainingFromRemote(PlaybackSession session, int offset) {
    return synchronizedRemainingMs(
      session: session,
      localNowMs: DateTime.now().millisecondsSinceEpoch,
      serverTimeOffsetMs: offset,
    );
  }

  void _setDeadline(PlayerState value) {
    _endsAt = value.isPaused
        ? null
        : DateTime.now().add(Duration(milliseconds: value.remainingMs));
  }

  void _tick() {
    if (state.isPaused || _endsAt == null || currentStep == null) return;
    final left = max(0, _endsAt!.difference(DateTime.now()).inMilliseconds);
    final previousSecond = state.secondsLeft;
    if (left != state.remainingMs) {
      state = state.copyWith(remainingMs: left);
      final second = state.secondsLeft;
      if (currentStep!.module.beep &&
          second > 0 &&
          second <= 3 &&
          second != previousSecond) {
        unawaited(ref.read(beepPlayerProvider).play());
      }
    }
    if (left <= 0 && !_transitioning) {
      if (canControl && sessionId != null) {
        unawaited(_seekRemote(state.index + 1, silent: true));
      } else {
        _goLocal(state.index + 1);
      }
    }
  }

  Future<void> toggle() async {
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
      if (!success) state = previous;
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

  Future<void> next() async {
    if (sessionId == null || !canControl) {
      _goLocal(state.index + 1);
      return;
    }
    await _seekRemote(state.index + 1);
  }

  Future<void> previous() async {
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

  Future<void> _seekRemote(int index, {bool silent = false}) async {
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
      _goLocal(safeIndex);
      final notifier = ref.read(playbackActionControllerProvider.notifier);
      final success = silent
          ? await notifier.syncStep(
              stepIndex: safeIndex,
              durationMs: state.steps[safeIndex].duration * 1000,
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

  void _goLocal(int index) {
    if (index >= state.steps.length) {
      _ticker?.cancel();
      state = state.copyWith(index: state.steps.length, remainingMs: 0);
      return;
    }
    final safeIndex = max(0, index);
    final next = state.copyWith(
      index: safeIndex,
      remainingMs: state.steps[safeIndex].duration * 1000,
      isPaused: false,
    );
    state = next;
    _setDeadline(next);
    if (currentStep?.module.beep == true) {
      unawaited(ref.read(beepPlayerProvider).play());
    }
  }
}
