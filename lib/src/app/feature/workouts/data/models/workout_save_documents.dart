import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

/// The exact two documents committed atomically by the app. The rules contract
/// exporter uses this same boundary, so a new serialized field is tested in CI.
class WorkoutSaveDocuments {
  WorkoutSaveDocuments(
    WorkoutModel model, {
    required bool contentOnly,
    Map<String, dynamic>? previous,
  }) {
    final entity = model.toEntity();
    final encoded = WorkoutDocument.encode(WorkoutContent.fromWorkout(entity));
    if (previous == null) {
      workout = encoded;
    } else {
      // A supported older DTO does not know every additive field introduced by
      // a newer client. Preserve those values from the transaction's server
      // read, while retaining deliberate deletions of fields this DTO knows.
      workout = _preserveUnknown(
        previous,
        encoded,
        WorkoutDocument.decode(previous).toJson(),
      );
    }
    if (!contentOnly) {
      workout.remove('schemaVersion');
      final defaults = model.toJson();
      for (final key in WorkoutDocument.legacySettingKeys) {
        workout[key] = previous != null ? previous[key] : defaults[key];
      }
    }
    summary = WorkoutSummaryModel.fromEntity(summarizeWorkout(entity)).toJson();
  }

  late final Map<String, dynamic> workout;
  late final Map<String, dynamic> summary;
}

Map<String, dynamic> _preserveUnknown(
  Map previous,
  Map<String, dynamic> next,
  Map knownPrevious,
) => {
  for (final key in previous.keys)
    if (!knownPrevious.containsKey(key) && !next.containsKey(key))
      key as String: previous[key],
  for (final entry in next.entries)
    entry.key: _preserveValue(
      previous[entry.key],
      entry.value,
      knownPrevious[entry.key],
    ),
};

Object? _preserveValue(Object? previous, Object? next, Object? knownPrevious) {
  if (previous is Map && next is Map && knownPrevious is Map) {
    return _preserveUnknown(
      previous,
      Map<String, dynamic>.from(next),
      knownPrevious,
    );
  }
  if (previous is List && next is List && knownPrevious is List) {
    // Never match list elements by index: reorder/deletion must not transfer
    // another slide's metadata. Modules and interval blocks have stable IDs.
    final oldById = {
      for (final value in previous)
        if (value is Map && value['id'] is String) value['id']: value,
    };
    final knownById = {
      for (final value in knownPrevious)
        if (value is Map && value['id'] is String) value['id']: value,
    };
    return [
      for (final value in next)
        if (value is Map && value['id'] is String)
          _preserveValue(oldById[value['id']], value, knownById[value['id']])
        else
          value,
    ];
  }
  return next;
}
