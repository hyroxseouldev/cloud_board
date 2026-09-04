import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';

@freezed
abstract class Workout with _$Workout {
  const factory Workout({
    required String id,
    required String name,
    required String folder,
    required String brandL,
    required String brandR,
    required List<WorkoutModule> modules,
    required DateTime updatedAt,
  }) = _Workout;

  factory Workout.empty(String id) => Workout(
    id: id,
    name: '',
    folder: '',
    brandL: 'XON TRAINING',
    brandR: '',
    modules: const [],
    updatedAt: DateTime.now(),
  );
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
    required String imageBase64,
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
    imageBase64: '',
    showTimer: true,
    beep: true,
    coverImage: false,
  );
}
