import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/usecases/ai_timer_actions.dart';
part 'ai_timer_controller.g.dart';

@riverpod
Future<AiTimerAccess> aiTimerAccess(Ref ref) =>
    ref.watch(aiTimerActionsProvider).access();

@riverpod
class AiTimerController extends _$AiTimerController {
  @override
  AsyncValue<AiTimerSuggestion?> build() => const AsyncData(null);
  Future<void> recognize(String imageSource) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(aiTimerActionsProvider).recognize(imageSource),
    );
    if (!ref.mounted) return;
    state = result;
    ref.invalidate(aiTimerAccessProvider);
  }
}
