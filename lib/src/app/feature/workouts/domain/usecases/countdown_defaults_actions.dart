import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/repositories/countdown_defaults_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/countdown_defaults_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
part 'countdown_defaults_actions.g.dart';

class CountdownDefaultsActions {
  CountdownDefaultsActions(this.repository);
  final CountdownDefaultsRepository repository;
  Future<CountdownPreferences> load(String ownerId) => repository.load(ownerId);
  Future<void> save(String ownerId, CountdownPreferences value) =>
      repository.save(ownerId, value);
}

@riverpod
CountdownDefaultsActions countdownDefaultsActions(Ref ref) =>
    CountdownDefaultsActions(ref.watch(countdownDefaultsRepositoryProvider));
