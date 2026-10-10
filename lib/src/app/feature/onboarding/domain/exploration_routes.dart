import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';

/// Only public fixtures are accepted. Never carry arbitrary return URLs/workout IDs.
StarterWorkout? starterFromKey(String? key) =>
    StarterWorkout.values.where((t) => t.key == key).firstOrNull;

String? explorationPurpose(String? value) =>
    const ['exploring', 'preparing', 'operating'].contains(value)
    ? value
    : null;

String starterLocation(
  String path,
  StarterWorkout? template, {
  String? purpose,
}) {
  final intent = explorationPurpose(purpose);
  final query = <String, String>{
    if (template != null) 'starter': template.key,
    'purpose': ?intent,
  };
  return Uri(
    path: path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

bool isExplorationPath(String path) =>
    path == '/explore' ||
    StarterWorkout.values.any((t) => path == '/explore/play/${t.key}');
