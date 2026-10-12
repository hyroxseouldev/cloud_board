/// Pure receipt matching. A write receipt is not a display acknowledgement.
enum PlaybackAckVerdict { pending, success, cancelled }

class PlaybackAckDevice {
  const PlaybackAckDevice(
    this.id,
    this.sessionId,
    this.revision, {
    this.paired = true,
  });
  final String id;
  final String? sessionId;
  final int revision;
  final bool paired;
}

PlaybackAckVerdict evaluatePlaybackAck({
  required String expectedSessionId,
  required int expectedRevision,
  required Set<String> targetIds,
  required String expectedDeviceId,
  required String? currentSessionId,
  required int? currentRevision,
  required String? currentDeviceId,
  required Set<String> currentTargetIds,
  required Iterable<PlaybackAckDevice> devices,
}) {
  if (targetIds.isEmpty ||
      currentSessionId != expectedSessionId ||
      (currentRevision != null && currentRevision > expectedRevision)) {
    return PlaybackAckVerdict.cancelled;
  }
  if (currentRevision == null || currentRevision < expectedRevision)
    return PlaybackAckVerdict.pending;
  if (currentDeviceId != expectedDeviceId ||
      currentTargetIds.length != targetIds.length ||
      !currentTargetIds.containsAll(targetIds))
    return PlaybackAckVerdict.cancelled;
  final targets = {
    for (final device in devices)
      if (targetIds.contains(device.id)) device.id: device,
  };
  if (targets.values.any(
    (device) =>
        device.sessionId == expectedSessionId &&
        device.revision > expectedRevision,
  )) {
    return PlaybackAckVerdict.cancelled;
  }
  if (targets.length == targetIds.length &&
      targets.values.every(
        (device) =>
            device.paired &&
            device.sessionId == expectedSessionId &&
            device.revision == expectedRevision,
      )) {
    return PlaybackAckVerdict.success;
  }
  return PlaybackAckVerdict.pending;
}
