import 'dart:math';

/// An opaque identifier for commands and diagnostics on native and web.
String createEventId({DateTime? now}) {
  // Dart web bitwise operations are 32-bit: `1 << 32` becomes zero.
  // Keep the supported Random.nextInt upper bound as an integer literal.
  final nonce = Random.secure().nextInt(0x100000000);
  final timestamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  return '${timestamp.toRadixString(36)}-${nonce.toRadixString(36)}';
}
