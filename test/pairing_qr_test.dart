import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/pairing_qr.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_pairing_card.dart';

void main() {
  test('QR accepts only exact codes and Cloud Board pairing payloads', () {
    expect(pairingCodeFromQr(pairingQrPayload('001234')), '001234');
    expect(pairingCodeFromQr(' 001234 '), '001234');
    for (final invalid in [
      'https://evil.test/?code=123456',
      'cloudboard://pair?code=123456&code=654321',
      'cloudboard://pair?code=123456&uid=account',
      'cloudboard://other?code=123456',
      '1234567',
      'hello123456',
      'cloudboard://pair?code=abcdef',
    ]) {
      expect(pairingCodeFromQr(invalid), isNull, reason: invalid);
    }
  });
  testWidgets(
    'expired pairing removes both QR and usable code, refresh remains available',
    (tester) async {
      final now = DateTime(2026, 9, 15);
      var refreshes = 0;
      final ticket = DevicePairing(
        code: '123456',
        deviceId: 'test',
        expiresAtMs: now.millisecondsSinceEpoch + 1000,
      );
      Future<void> pump(DateTime at) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DisplayPairingCard(
                ticket: ticket,
                now: at,
                onRefresh: () => refreshes++,
              ),
            ),
          ),
        ),
      );
      await pump(now);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('0:01'), findsOneWidget);
      await pump(now.add(const Duration(seconds: 1)));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('123456'), findsNothing);
      await tester.tap(find.byTooltip('새 연결 코드'));
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
