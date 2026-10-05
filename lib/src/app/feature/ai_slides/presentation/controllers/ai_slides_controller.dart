import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
part 'ai_slides_controller.g.dart';

@riverpod
Future<AiSlidesAccess> aiSlidesAccess(Ref ref) =>
    ref.watch(aiSlidesActionsProvider).access();

@riverpod
class AiSlidesController extends _$AiSlidesController {
  @override
  AsyncValue<AiSlidesResult?> build() => const AsyncData(null);
  Future<void> generate(String prompt) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(aiSlidesActionsProvider).generate(prompt),
    );
    if (!ref.mounted) return;
    state = result;
    ref.invalidate(aiSlidesAccessProvider);
  }
}
