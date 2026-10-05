import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

const slideDesignMaxLines = 24;
const slideDesignMaxLineLength = 120;
const slideDesignMaxTextLength =
    slideDesignMaxLines * (slideDesignMaxLineLength + 1) - 1;

const slideDesigns = <String, String>{
  'stationd-v1-numbered': '웜업 · 번호 목록',
  'stationd-v1-list': '운동 목록',
  'stationd-v1-interval': '인터벌',
};

bool hasSlideDesign(WorkoutModule module) =>
    slideDesigns.containsKey(module.designTemplate);

List<String> slideDesignLines(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

String? slideDesignError(WorkoutModule module) {
  if (!hasSlideDesign(module)) return null;
  if (module.name.trim().isEmpty || module.name.length > 60) {
    return '테마 슬라이드 제목은 1~60자로 입력해 주세요.';
  }
  final lines = slideDesignLines(module.text);
  if (lines.length > slideDesignMaxLines ||
      lines.any((line) => line.length > slideDesignMaxLineLength)) {
    return '테마 슬라이드는 최대 24줄, 한 줄에 120자까지 입력할 수 있어요.';
  }
  return null;
}
