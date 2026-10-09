import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_identification_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_verification.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

class _Identification extends DisplayIdentificationController {
  _Identification(this.expired);
  final bool expired;
  int calls = 0;
  @override
  AsyncValue<DisplayIdentification?> build(String deviceId) => AsyncData((
    nonce: 'attempt-4321',
    expiresAtMs:
        DateTime.now().millisecondsSinceEpoch + (expired ? -1000 : 60000),
  ));
  @override
  Future<void> identify() async {
    calls++;
  }
}

class _Progress extends FirstClassController {
  final confirmed = <String>[];
  @override
  Future<FirstClassProgress?> build() async =>
      const FirstClassProgress(sessionId: 's');
  @override
  Future<void> verified(String deviceId) async {
    confirmed.add(deviceId);
  }
}

DisplayDevice tv(
  String? ack, {
  String id = 'tv',
  String nonce = 'attempt-4321',
}) => DisplayDevice(
  id: id,
  name: '메인 TV',
  zoneId: 'main',
  zoneName: 'main',
  online: true,
  lastSeenAtMs: 0,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
  pairingCode: '123456',
  identificationId: nonce,
  identificationAck: ack,
);

void main() {
  testWidgets(
    'claim/online/stale ACK cannot confirm; matching TV ACK still needs human confirmation',
    (tester) async {
      final devices = StreamController<List<DisplayDevice>>.broadcast();
      final attempt = _Identification(false);
      final progress = _Progress();
      var finished = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayDevicesProvider.overrideWith((_) => devices.stream),
            displayIdentificationControllerProvider.overrideWith2(
              (_) => attempt,
            ),
            firstClassControllerProvider.overrideWith(() => progress),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DisplayVerification(
                  deviceId: 'tv',
                  onDone: () => finished = true,
                ),
              ),
            ),
          ),
        ),
      );
      devices.add([tv(null)]);
      await tester.pumpAndSettle();
      bool canConfirm() =>
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '이 TV가 맞아요'),
              )
              .onPressed !=
          null;
      expect(canConfirm(), isFalse);
      devices.add([tv('old-attempt'), tv('attempt-4321', id: 'other')]);
      await tester.pumpAndSettle();
      expect(canConfirm(), isFalse);
      devices.add([tv('attempt-4321')]);
      await tester.pumpAndSettle();
      expect(canConfirm(), isTrue);
      expect(finished, isFalse);
      await tester.tap(find.text('이 TV가 맞아요'));
      await tester.pumpAndSettle();
      expect(progress.confirmed, ['tv']);
      expect(finished, isTrue);
      expect(attempt.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await devices.close();
    },
  );

  testWidgets(
    'expired attempt explains retry and does not accept an old matching ACK',
    (tester) async {
      final attempt = _Identification(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            displayDevicesProvider.overrideWith(
              (_) => Stream.value([tv('attempt-4321')]),
            ),
            displayIdentificationControllerProvider.overrideWith2(
              (_) => attempt,
            ),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DisplayVerification(
                  deviceId: 'tv',
                  onDone: () => fail('Expired ACK was accepted'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('TV의 응답을 받지 못했습니다'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '이 TV가 맞아요'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('확인 화면 다시 보내기'));
      await tester.pumpAndSettle();
      expect(attempt.calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
