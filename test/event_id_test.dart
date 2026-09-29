import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('command and diagnostic IDs are safe in the JavaScript runtime', () {
    final now = DateTime.utc(2026, 9, 30);
    final prefix = '${now.microsecondsSinceEpoch.toRadixString(36)}-';
    // Run this test on Chrome as well as the VM: the former fails with 1 << 32.
    for (var i = 0; i < 100; i++) {
      final id = createEventId(now: now);
      expect(id, startsWith(prefix));
      expect(id, matches(RegExp(r'^[a-z0-9-]{8,80}$')));
      final nonce = int.parse(id.substring(prefix.length), radix: 36);
      expect(nonce, inInclusiveRange(0, 0xffffffff));
    }
  });
}
