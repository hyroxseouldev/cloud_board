import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

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
  bool finishTimer = false,
}) {
  if (session.id != expectedSessionId) {
    throw const PlaybackFailure(
      'session_changed',
      '다른 수업으로 변경되었습니다. 최신 수업을 확인해 주세요.',
    );
  }
  if (session.revision != expectedRevision) {
    throw PlaybackFailure(
      'revision_conflict',
      '다른 컨트롤러의 조작이 먼저 반영되었습니다. 최신 상태를 확인해 주세요.',
      expectedRevision: expectedRevision,
      observedRevision: session.revision,
    );
  }
  if (session.status == PlaybackStatus.completed) {
    throw const PlaybackFailure('session_completed', '이미 종료된 수업입니다.');
  }
  if (serverNowMs >= expiresAtMs) {
    throw const PlaybackFailure(
      'command_expired',
      '명령의 유효 시간이 지났습니다. 최신 상태를 확인해 주세요.',
    );
  }
  if (requireBriefing && !session.briefing) {
    throw const PlaybackFailure('already_started', '이미 시작한 수업입니다.');
  }
  final durations = playbackDurations(session.workout);
  final position = playbackPosition(session, durations, serverNowMs);
  if (status != 'completed' &&
      (position.index >= durations.length ||
          (!requireBriefing && session.briefing))) {
    throw const PlaybackFailure('status_changed', '종료되었거나 시작 준비 중인 수업입니다.');
  }
  if (!requireBriefing &&
      !finishTimer &&
      ((status == 'playing' && session.status != PlaybackStatus.paused) ||
          (status == 'paused' && session.status != PlaybackStatus.playing))) {
    throw const PlaybackFailure('status_changed', '다른 컨트롤러에서 재생 상태를 변경했습니다.');
  }
  final forTime = playbackForTimeFlags(session.workout);
  final currentForTime =
      position.index < forTime.length && forTime[position.index];
  if (finishTimer &&
      (!currentForTime ||
          position.countdownMs > 0 ||
          session.timerCompleted ||
          (durations[position.index] > 0 && position.remainingMs == 0))) {
    throw const PlaybackFailure(
      'timer_finish_unavailable',
      '운동 완료할 For Time 타이머가 없습니다.',
    );
  }
  if (status == 'playing' &&
      !requireBriefing &&
      (session.timerCompleted ||
          (currentForTime &&
              durations[position.index] > 0 &&
              position.remainingMs == 0))) {
    throw const PlaybackFailure(
      'timer_finished',
      '완료된 타이머입니다. 다음 운동으로 이동하거나 처음부터 다시 시작해 주세요.',
    );
  }
  if (stepIndex != null && (stepIndex < 0 || stepIndex >= durations.length)) {
    throw const PlaybackFailure('invalid_position', '이동할 슬라이드를 찾을 수 없습니다.');
  }
  return (
    status:
        status ??
        (stepIndex != null &&
                (position.countdownMs > 0 ||
                    session.timerCompleted ||
                    (currentForTime &&
                        durations[position.index] > 0 &&
                        position.remainingMs == 0))
            ? 'playing'
            : session.status.name),
    stepIndex: stepIndex ?? position.index,
    remainingMs: status == 'completed'
        ? 0
        : status == 'paused'
        ? position.remainingMs
        : remainingMs ?? position.remainingMs,
  );
}
