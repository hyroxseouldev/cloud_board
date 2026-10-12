import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_recovery_repository.dart';

part 'workout_recovery_controller.g.dart';

class WorkoutRecoveryState {
  const WorkoutRecoveryState({this.loading = true, this.recovered, this.error});
  final bool loading;
  final WorkoutRecoveryDraft? recovered;
  final String? error;
}

@riverpod
class WorkoutRecoveryController extends _$WorkoutRecoveryController {
  late WorkoutRecoveryRepository _repository;
  late String _ownerId, _slot;
  Timer? _debounce;
  WorkoutRecoveryDraft? _latest;
  int _revision = 0;
  bool _accepted = false;

  @override
  WorkoutRecoveryState build(String ownerId, String slot) {
    _ownerId = ownerId;
    _slot = slot;
    if (ownerId.isEmpty) {
      // Auth transitions can retain a read-only cached editor for a frame.
      // Never open another account's recovery store without an active account.
      return const WorkoutRecoveryState(loading: false);
    }
    _repository = ref.watch(workoutRecoveryRepositoryProvider);
    Future.microtask(_restore);
    ref.onDispose(() {
      _debounce?.cancel();
      final latest = _latest;
      if (latest != null) {
        unawaited(
          _repository.save(_ownerId, _slot, latest).catchError((Object _) {}),
        );
      }
    });
    return const WorkoutRecoveryState();
  }

  Future<void> _restore() async {
    try {
      final draft = await _repository.load(_ownerId, _slot);
      if (ref.mounted) {
        state = WorkoutRecoveryState(loading: false, recovered: draft);
      }
    } catch (_) {
      if (ref.mounted) {
        state = const WorkoutRecoveryState(
          loading: false,
          error: '이 기기의 임시저장을 읽지 못했어요.',
        );
      }
    }
  }

  void accept() {
    _accepted = true;
    state = const WorkoutRecoveryState(loading: false);
  }

  void record(Workout workout, {required bool isNew}) {
    if (!_accepted || _ownerId.isEmpty || workout.ownerId != _ownerId) return;
    _latest = WorkoutRecoveryDraft(workout: workout, isNew: isNew);
    _revision++;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(flush()),
    );
  }

  Future<bool> flush() async {
    _debounce?.cancel();
    final draft = _latest;
    if (draft == null) return true;
    final revision = _revision;
    try {
      await _repository.save(_ownerId, _slot, draft);
      if (ref.mounted && revision == _revision) {
        state = const WorkoutRecoveryState(loading: false);
      }
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = const WorkoutRecoveryState(
          loading: false,
          error: '임시저장에 실패했어요. 앱을 닫기 전에 저장을 다시 시도해 주세요.',
        );
      }
      return false;
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    _latest = null;
    _revision++;
    _accepted = true;
    if (_ownerId.isEmpty) return;
    try {
      await _repository.clear(_ownerId, _slot);
    } catch (_) {
      if (ref.mounted) {
        state = const WorkoutRecoveryState(
          loading: false,
          error: '임시저장을 정리하지 못했어요. 이 기기에 이전 편집 내용이 남아 있을 수 있어요.',
        );
      }
      return;
    }
    if (ref.mounted) state = const WorkoutRecoveryState(loading: false);
  }
}
