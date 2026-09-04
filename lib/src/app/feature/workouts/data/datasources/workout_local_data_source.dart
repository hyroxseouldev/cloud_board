import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_model.dart';

part 'workout_local_data_source.g.dart';

class WorkoutLocalDataSource {
  WorkoutLocalDataSource(this._preferences);
  static const _storageKey = 'xonboard.v1';
  final SharedPreferences _preferences;

  List<WorkoutModel> load() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final value = jsonDecode(raw) as Map<String, dynamic>;
    return (value['workouts'] as List<dynamic>? ?? const [])
        .map((item) => WorkoutModel.fromJson(_upgradeLegacyWorkout(item)))
        .toList();
  }

  Map<String, dynamic> _upgradeLegacyWorkout(dynamic item) {
    final workout = Map<String, dynamic>.from(item as Map);
    final updatedAt = workout['updatedAt'] ?? 0;
    workout
      ..putIfAbsent('ownerId', () => '')
      ..putIfAbsent(
        'author',
        () => <String, dynamic>{'id': '', 'displayName': '', 'photoUrl': null},
      )
      ..putIfAbsent('createdAt', () => updatedAt);
    workout['modules'] = (workout['modules'] as List<dynamic>? ?? const []).map(
      (module) {
        final value = Map<String, dynamic>.from(module as Map);
        value.putIfAbsent('imageUrl', () => value['imageBase64'] ?? '');
        value.remove('imageBase64');
        return value;
      },
    ).toList();
    return workout;
  }

  Future<void> save(List<WorkoutModel> workouts) => _preferences.setString(
    _storageKey,
    jsonEncode({'workouts': workouts.map((item) => item.toJson()).toList()}),
  );

  Future<void> clear() => _preferences.remove(_storageKey);
}

@riverpod
Future<WorkoutLocalDataSource> workoutLocalDataSource(Ref ref) async =>
    WorkoutLocalDataSource(await SharedPreferences.getInstance());
