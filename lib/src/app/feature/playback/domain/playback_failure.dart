/// A rejected command retains the exact reason and revisions for diagnostics.
/// Never replay a stale seek/end against a newer session automatically.
class PlaybackFailure implements Exception {
  const PlaybackFailure(
    this.code,
    this.message, {
    this.expectedRevision,
    this.observedRevision,
    this.commandId,
  });
  final String code;
  final String message;
  final int? expectedRevision;
  final int? observedRevision;
  final String? commandId;
  bool get needsRefresh => const {
    'revision_conflict',
    'session_changed',
    'command_expired',
    'status_changed',
    'already_started',
    'session_completed',
    'invalid_position',
  }.contains(code);
  @override
  String toString() => 'PlaybackFailure[$code]: $message';
}
