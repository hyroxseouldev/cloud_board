class WorkoutWriteConflict implements Exception {
  const WorkoutWriteConflict();
  @override
  String toString() => '다른 기기에서 이 워크아웃을 수정했어요. 편집 내용을 복사본으로 저장해 주세요.';
}

/// Version checks happen inside the same transaction as the write. A refreshed
/// catalog must never replace the version on which an open editor is based.
void ensureWorkoutRevision({
  required DateTime? expected,
  required DateTime? current,
  bool requireExisting = false,
}) {
  if (requireExisting && current == null) throw const WorkoutWriteConflict();
  if (expected != null &&
      current != null &&
      !expected.isAtSameMomentAs(current)) {
    throw const WorkoutWriteConflict();
  }
}
