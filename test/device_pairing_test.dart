import 'dart:math';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairing code is always six numeric characters', () {
    for (var seed = 0; seed < 100; seed++) {
      expect(generatePairingCode(Random(seed)), matches(RegExp(r'^\d{6}$')));
    }
  });

  test('pairing expiration uses its absolute timestamp', () {
    final expired = DevicePairing(
      code: '123456',
      deviceId: 'device',
      expiresAtMs: DateTime.now()
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch,
    );

    expect(expired.isExpired, isTrue);
  });
}
