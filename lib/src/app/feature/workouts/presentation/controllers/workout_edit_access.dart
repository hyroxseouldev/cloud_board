import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';

const workoutPlayingEditMessage = '수업 진행 중에는 이 워크아웃을 편집할 수 없습니다.';

String? workoutEditBlockReason(
  AsyncValue<PlaybackSession?> session,
  String workoutId,
) {
  if (workoutId == 'new') return null;
  // Retain a known running lock while refreshing or after a stream error.
  final value = session.value;
  if (value?.workout.id == workoutId &&
      value?.status != PlaybackStatus.completed) {
    return workoutPlayingEditMessage;
  }
  if (session.hasError) return '수업 상태를 확인하지 못했습니다. 연결을 확인해 주세요.';
  if (session.isLoading) return '수업 상태를 확인하고 있습니다.';
  return null;
}
