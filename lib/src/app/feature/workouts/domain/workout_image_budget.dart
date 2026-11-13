/// Stored image bytes, in decimal MB. The same asset counts once per workout.
const workoutImageLimitBytes = 100000000;

String imageMegabytes(int bytes) {
  final value = bytes / 1000000;
  if (bytes > 0 && value < .01) return '<0.01 MB';
  return '${value.toStringAsFixed(2)} MB';
}

class WorkoutImageUsage {
  const WorkoutImageUsage({
    required this.moduleBytes,
    required this.countdownBytes,
    required this.knownBytes,
    required this.unknownCount,
    this.failed = false,
  });
  final Map<String, int?> moduleBytes;
  final int? countdownBytes;
  final int knownBytes, unknownCount;
  final bool failed;
  bool get exceedsLimit => knownBytes > workoutImageLimitBytes;
  String get totalLabel =>
      '${unknownCount > 0 ? '확인된 ' : ''}${imageMegabytes(knownBytes)} / 100 MB';
}

class WorkoutImageBudgetExceeded implements Exception {
  const WorkoutImageBudgetExceeded(this.bytes);
  final int bytes;
  String get message =>
      '워크아웃 이미지는 총 100 MB까지 저장할 수 있어요. '
      '${imageMegabytes(bytes - workoutImageLimitBytes)} 초과했어요. '
      '큰 이미지를 줄이거나 슬라이드 이미지를 삭제한 뒤 다시 저장해 주세요.';
}
