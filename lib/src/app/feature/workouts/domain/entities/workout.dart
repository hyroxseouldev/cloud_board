import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';

@freezed
abstract class Workout with _$Workout {
  const factory Workout({
    required String id,
    required String ownerId,
    required WorkoutAuthor author,
    required String name,
    required String folder,
    required String brandL,
    required String brandR,
    required List<WorkoutModule> modules,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Workout;

  factory Workout.empty(String id, WorkoutAuthor author) => Workout(
    id: id,
    ownerId: author.id,
    author: author,
    name: '',
    folder: '',
    brandL: 'XON TRAINING',
    brandR: '',
    modules: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

@freezed
abstract class WorkoutAuthor with _$WorkoutAuthor {
  const factory WorkoutAuthor({
    required String id,
    required String displayName,
    required String? photoUrl,
  }) = _WorkoutAuthor;
}

@freezed
abstract class WorkoutModule with _$WorkoutModule {
  const factory WorkoutModule({
    required String id,
    required String name,
    required int workSeconds,
    required int sets,
    required int restSeconds,
    required String text,
    required String imageSource,
    required bool showTimer,
    required bool beep,
    required bool coverImage,
  }) = _WorkoutModule;

  factory WorkoutModule.empty(String id) => WorkoutModule(
    id: id,
    name: '',
    workSeconds: 60,
    sets: 1,
    restSeconds: 0,
    text: '',
    imageSource: '',
    showTimer: true,
    beep: true,
    coverImage: false,
  );
}
