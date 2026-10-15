class WorkoutWriteConflict implements Exception {
  const WorkoutWriteConflict();
  @override
  String toString() => '다른 기기에서 이 워크아웃을 수정했어요. 편집 내용을 복사본으로 저장해 주세요.';
}
