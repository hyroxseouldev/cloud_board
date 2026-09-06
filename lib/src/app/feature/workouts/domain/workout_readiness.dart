import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

class WorkoutReadiness {
  const WorkoutReadiness(this.issues);
  final List<String> issues;
  bool get isReady => issues.isEmpty;
}

WorkoutReadiness evaluateWorkoutReadiness(Workout workout) {
  final issues = <String>[];
  if (workout.name.trim().isEmpty) issues.add('워크아웃 이름이 없습니다.');
  if (workout.modules.isEmpty) issues.add('슬라이드가 없습니다.');
  for (var index = 0; index < workout.modules.length; index++) {
    final module = workout.modules[index];
    final label = '${index + 1}번 슬라이드';
    if (module.name.trim().isEmpty) issues.add('$label 이름이 없습니다.');
    if (module.workSeconds < 1 || module.sets < 1) {
      issues.add('$label 운동 시간이 올바르지 않습니다.');
    }
    final source = module.imageSource;
    if (source.isNotEmpty &&
        !source.startsWith('http://') &&
        !source.startsWith('https://')) {
      try {
        final decoded = WorkoutImageSource.decode(source);
        if (!WorkoutImageSource.supportedContentTypes.contains(
          decoded.contentType,
        )) {
          issues.add('$label 이미지 형식이 올바르지 않습니다.');
        }
      } on FormatException {
        issues.add('$label 이미지 형식이 올바르지 않습니다.');
      }
    }
  }
  return WorkoutReadiness(List.unmodifiable(issues));
}
