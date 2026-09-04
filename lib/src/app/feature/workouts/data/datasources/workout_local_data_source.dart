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
        .map(
          (item) =>
              WorkoutModel.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> save(List<WorkoutModel> workouts) => _preferences.setString(
    _storageKey,
    jsonEncode({'workouts': workouts.map((item) => item.toJson()).toList()}),
  );
}

@riverpod
Future<WorkoutLocalDataSource> workoutLocalDataSource(Ref ref) async =>
    WorkoutLocalDataSource(await SharedPreferences.getInstance());
