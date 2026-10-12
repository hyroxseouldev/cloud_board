import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

/// Accumulated catalog rows. Cache is provisional; only a complete server page
/// can establish deletions or claim the entire catalog has been loaded.
class WorkoutCatalogPage {
  const WorkoutCatalogPage(
    this.items, {
    this.cached = false,
    this.complete = false,
    this.ordered = false,
  });
  final List<WorkoutSummary> items;
  final bool cached;
  final bool complete;

  /// Newest first, with a stable ID tie breaker.
  final bool ordered;
}

abstract interface class PagedWorkoutCatalog {
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false});
}

/// Shared ordering prevents a second full-list sort in presentation.
int compareWorkoutSummaries(WorkoutSummary a, WorkoutSummary b) {
  final date = b.updatedAt.compareTo(a.updatedAt);
  return date != 0 ? date : a.id.compareTo(b.id);
}

/// Merge only changed rows into an already ordered snapshot. The unchanged
/// rows retain their identity; at most the changed page is sorted.
List<WorkoutSummary> mergeWorkoutSummaries(
  List<WorkoutSummary> ordered,
  Map<String, WorkoutSummary> changes, {
  Set<String> removed = const {},
}) {
  if (changes.isEmpty && removed.isEmpty) return ordered;
  final changed =
      changes.values.where((item) => !removed.contains(item.id)).toList()
        ..sort(compareWorkoutSummaries);
  final result = <WorkoutSummary>[];
  var next = 0;
  for (final item in ordered) {
    if (changes.containsKey(item.id) || removed.contains(item.id)) continue;
    while (next < changed.length &&
        compareWorkoutSummaries(changed[next], item) < 0) {
      result.add(changed[next++]);
    }
    result.add(item);
  }
  result.addAll(changed.skip(next));
  return List.unmodifiable(result);
}
