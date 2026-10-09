import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

import 'package:cloud_board/src/app/feature/ai_timer/data/repositories/ai_timer_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/repositories/ai_timer_repository.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
part 'ai_timer_actions.g.dart';

@riverpod
AiTimerActions aiTimerActions(Ref ref) =>
    AiTimerActions(ref.watch(aiTimerRepositoryProvider));

class AiTimerActions {
  const AiTimerActions(this.repository);
  final AiTimerRepository repository;
  Future<AiTimerAccess> access() => repository.access();
  Future<AiTimerSuggestion> recognize(String source) async {
    final access = await repository.access();
    if (!access.premium) {
      throw const AiTimerFailure(
        '프리미엄 이용자만 사용할 수 있어요.',
        code: 'premium-required',
      );
    }
    if (!access.enabled) {
      throw const AiTimerFailure('AI 기능을 준비 중입니다.', code: 'not-configured');
    }
    // Let the server return a free cached result even when remaining is zero.
    return repository.recognize(source);
  }
}

bool canApplyAiTimer(WorkoutModule before, WorkoutModule current) =>
    before.id == current.id &&
    before.imageSource == current.imageSource &&
    sameSlideTiming(before, current);

bool supportsAiTimerReplacement(WorkoutModule module) =>
    !needsExtendedTiming(module) &&
    module.timerMode == WorkoutTimerMode.custom &&
    module.timerDirection == TimerDirection.down &&
    effectiveIntervalBlocks(module).length == 1;

WorkoutModule applyAiTimer(
  WorkoutModule module, {
  required int workSeconds,
  required int restSeconds,
  required int sets,
  String? name,
}) {
  if (!supportsAiTimerReplacement(module)) {
    throw const AiTimerFailure('복합 타이머는 직접 편집하거나 EMOM 간편 만들기를 사용해 주세요.');
  }
  if (workSeconds < 1 ||
      workSeconds > 3600 ||
      restSeconds < 0 ||
      restSeconds > 3600 ||
      sets < 1 ||
      sets > 100) {
    throw const AiTimerFailure('운동·휴식 시간과 세트를 확인해 주세요.');
  }
  return module.copyWith(
    timingVersion: 2,
    workSeconds: workSeconds,
    restSeconds: restSeconds,
    sets: sets,
    intervalBlocks: const [],
    name: name?.trim().isNotEmpty == true ? name!.trim() : module.name,
  );
}
