import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/observability/playback_ack.dart';

void main() {
  PlaybackAckVerdict check(
    List<PlaybackAckDevice> devices, {
    String? session = 's',
    int revision = 4,
    String owner = 'phone',
    Set<String> targets = const {'tv1', 'tv2'},
  }) => evaluatePlaybackAck(
    expectedSessionId: 's',
    expectedRevision: 4,
    targetIds: {'tv1', 'tv2'},
    expectedDeviceId: 'phone',
    currentSessionId: session,
    currentRevision: revision,
    currentDeviceId: owner,
    currentTargetIds: targets,
    devices: devices,
  );
  const exact = [
    PlaybackAckDevice('tv1', 's', 4),
    PlaybackAckDevice('tv2', 's', 4),
  ];
  test(
    'requires every exact session and revision ACK; old receipt is pending',
    () {
      expect(check(exact), PlaybackAckVerdict.success);
      expect(check([exact.first]), PlaybackAckVerdict.pending);
      expect(
        check([exact.first, const PlaybackAckDevice('tv2', 'old', 4)]),
        PlaybackAckVerdict.pending,
      );
      expect(
        check([exact.first, const PlaybackAckDevice('tv2', 's', 3)]),
        PlaybackAckVerdict.pending,
      );
      expect(check(exact, revision: 3), PlaybackAckVerdict.pending);
      expect(
        check([
          exact.first,
          const PlaybackAckDevice('tv2', 's', 4, paired: false),
        ]),
        PlaybackAckVerdict.pending,
      );
    },
  );
  test(
    'superseding session/revision/owner/targets never makes old ACK successful',
    () {
      expect(check(exact, session: 'new'), PlaybackAckVerdict.cancelled);
      expect(check(exact, session: null), PlaybackAckVerdict.cancelled);
      expect(check(exact, revision: 5), PlaybackAckVerdict.cancelled);
      expect(check(exact, owner: 'other'), PlaybackAckVerdict.cancelled);
      expect(
        check(exact, targets: {'tv1', 'tv3'}),
        PlaybackAckVerdict.cancelled,
      );
      expect(
        check([exact.first, const PlaybackAckDevice('tv2', 's', 5)]),
        PlaybackAckVerdict.cancelled,
      );
    },
  );
}
