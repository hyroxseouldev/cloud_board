import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

// The existing saveWorkout wire, including the same author and timestamp units.
Map<String, dynamic> admissionWorkoutWire(Workout workout) {
  Object? wire(Object? value) => switch (value) {
    Timestamp value => value.millisecondsSinceEpoch,
    Map value => value.map((key, item) => MapEntry(key.toString(), wire(item))),
    List value => value.map(wire).toList(),
    _ => value,
  };
  return Map<String, dynamic>.from(
    wire(WorkoutModel.fromEntity(workout).toJson()) as Map,
  );
}
