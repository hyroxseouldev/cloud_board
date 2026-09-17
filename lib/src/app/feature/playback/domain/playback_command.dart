import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';

/// Freeze intent at its observed revision. A transaction retry must never turn
/// an old tap into a new command against a newer pause/seek/end.
({String status, int stepIndex, int remainingMs}) resolvePlaybackCommand({
  required PlaybackSession session,
  required String expectedSessionId,
  required int expectedRevision,
  required int serverNowMs,
  required int expiresAtMs,
  required String? status,
  int? stepIndex,
  int? remainingMs,
  bool requireBriefing = false,
}) {
  if (session.id != expectedSessionId ||
      session.revision != expectedRevision ||
      session.status == PlaybackStatus.completed ||
      serverNowMs >= expiresAtMs) {
    throw StateError('수업 상태가 변경되었거나 명령이 만료됐습니다.');
  }
  if (requireBriefing && !session.briefing) throw StateError('이미 시작한 수업입니다.');
  final durations = playbackDurations(session.workout);
  final position = playbackPosition(session, durations, serverNowMs);
  if (status != 'completed' &&
      (position.index >= durations.length ||
          (!requireBriefing &&
              (session.briefing || position.countdownMs > 0)))) {
    throw StateError('종료되었거나 시작 준비 중인 수업입니다.');
  }
  if (!requireBriefing &&
      ((status == 'playing' && session.status != PlaybackStatus.paused) ||
          (status == 'paused' && session.status != PlaybackStatus.playing))) {
    throw StateError('재생 상태가 변경되었습니다.');
  }
  if (stepIndex != null && (stepIndex < 0 || stepIndex >= durations.length)) {
    throw StateError('이동할 슬라이드를 찾을 수 없습니다.');
  }
  return (
    status: status ?? session.status.name,
    stepIndex: stepIndex ?? position.index,
    remainingMs: status == 'completed'
        ? 0
        : status == 'paused'
        ? position.remainingMs
        : remainingMs ?? position.remainingMs,
  );
}
