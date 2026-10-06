import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

/// Accumulated catalog rows. Cache is provisional; only a complete server page
/// can establish deletions or claim the entire catalog has been loaded.
class WorkoutCatalogPage {
  const WorkoutCatalogPage(
    this.items, {
    this.cached = false,
    this.complete = false,
  });
  final List<WorkoutSummary> items;
  final bool cached;
  final bool complete;
}

abstract interface class PagedWorkoutCatalog {
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false});
}
