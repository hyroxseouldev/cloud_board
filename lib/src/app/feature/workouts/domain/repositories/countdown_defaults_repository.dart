import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';

abstract interface class CountdownDefaultsRepository {
  Future<CountdownPreferences> load(String ownerId);
  Future<void> save(String ownerId, CountdownPreferences value);
}
