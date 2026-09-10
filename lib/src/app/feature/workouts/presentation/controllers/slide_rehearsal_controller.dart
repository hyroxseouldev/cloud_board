import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
part 'slide_rehearsal_controller.g.dart';

class RehearsalState {
  const RehearsalState({this.positionMs = 0, this.playing = false});
  final int positionMs;
  final bool playing;
}

@riverpod
class SlideRehearsalController extends _$SlideRehearsalController {
  Timer? _timer;
  DateTime? _anchor;
  int _anchorPosition = 0;
  int get totalMs => workoutModuleDuration(module) * 1000;
  @override
  RehearsalState build(WorkoutModule module) {
    ref.onDispose(() => _timer?.cancel());
    return const RehearsalState();
  }

  void pause() {
    _timer?.cancel();
    state = RehearsalState(positionMs: state.positionMs);
  }

  void seek(int positionMs) {
    pause();
    state = RehearsalState(positionMs: positionMs.clamp(0, totalMs));
  }

  void play() {
    if (totalMs <= 0) return;
    _timer?.cancel();
    _anchorPosition = state.positionMs >= totalMs ? 0 : state.positionMs;
    _anchor = DateTime.now();
    state = RehearsalState(positionMs: _anchorPosition, playing: true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final position =
          (_anchorPosition + DateTime.now().difference(_anchor!).inMilliseconds)
              .clamp(0, totalMs);
      state = RehearsalState(positionMs: position, playing: position < totalMs);
      if (position >= totalMs) _timer?.cancel();
    });
  }
}
