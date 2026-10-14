/// Local verification for the current physical RTDB connection. A historical
/// successful registration is not readiness for a later connection generation.
enum DisplayConnectionPhase { idle, verifying, ready, failed }

class DisplayConnectionState {
  const DisplayConnectionState({
    this.phase = DisplayConnectionPhase.idle,
    this.generation = 0,
    this.error,
    this.stack,
  });

  final DisplayConnectionPhase phase;
  final int generation;
  final Object? error;
  final StackTrace? stack;
}
