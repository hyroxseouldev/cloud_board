import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/countdown_defaults_actions.dart';
part 'countdown_defaults_controller.g.dart';

@riverpod
class CountdownDefaultsController extends _$CountdownDefaultsController {
  @override
  AsyncValue<String?> build(String ownerId) => const AsyncData(null);

  Future<CountdownPreferences?> load() async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    CountdownPreferences? loaded;
    final result = await AsyncValue.guard(() async {
      loaded = await ref.read(countdownDefaultsActionsProvider).load(ownerId);
      return null as String?;
    });
    if (ref.mounted) state = result;
    return result.hasError ? null : loaded;
  }

  Future<bool> save(CountdownPreferences value) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(countdownDefaultsActionsProvider).save(ownerId, value);
      return '내 기본값으로 저장했습니다. 새 워크아웃부터 적용됩니다.';
    });
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}

// A creation-time snapshot. Settings saves do not invalidate an open draft.
@riverpod
Future<CountdownPreferences> newWorkoutCountdownDefaults(
  Ref ref,
  String ownerId,
) => ref.watch(countdownDefaultsActionsProvider).load(ownerId);
