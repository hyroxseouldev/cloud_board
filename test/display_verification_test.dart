import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/first_tv_connection_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Progress extends FirstClassController {
  _Progress(this.previousDevice);
  final String? previousDevice;
  @override
  Future<FirstClassProgress?> build() async => FirstClassProgress(
    sessionId: 's',
    savedWorkoutId: 'saved',
    rehearsedWorkoutId: 'saved',
    verifiedDeviceId: previousDevice,
  );
}

DisplayDevice tv() => DisplayDevice(
  id: 'new-tv',
  name: '메인 TV',
  zoneId: 'main',
  zoneName: '메인 구역',
  online: true,
  lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
);

void main() {
  testWidgets(
    'TV connection guide lists registration without a response challenge',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstClassScopeProvider.overrideWith(
              (_) async =>
                  (userId: 'owner', centerId: 'center', centerReady: true),
            ),
            displayDevicesProvider.overrideWith((_) => Stream.value([tv()])),
            displayHealthNowProvider.overrideWith(
              (_) => Stream.value(DateTime.now().millisecondsSinceEpoch),
            ),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: const FirstTvConnectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TV 응답 확인'), findsNothing);
      expect(find.textContaining('확인 번호'), findsNothing);
      final row = tester.widget<ListTile>(
        find.widgetWithText(ListTile, '메인 TV'),
      );
      expect(row.onTap, isNull);
      expect(row.trailing, isNull);
      expect(find.text('메인 구역 · 온라인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final previousDevice in [null, 'removed-tv']) {
    for (final home in [false, true]) {
      testWidgets(
        'first class offers playback without a challenge (old=$previousDevice, home=$home)',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                firstClassControllerProvider.overrideWith(
                  () => _Progress(previousDevice),
                ),
                displayDevicesProvider.overrideWith(
                  (_) => Stream.value([tv()]),
                ),
                displayHealthNowProvider.overrideWith(
                  (_) => Stream.value(DateTime.now().millisecondsSinceEpoch),
                ),
              ],
              child: MaterialApp(
                theme: XonTheme.light,
                home: home
                    ? const Scaffold(body: FirstClassHomeCard())
                    : const FirstClassScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('연결한 TV에서 첫 수업 시작'), findsOneWidget);
          expect(find.text('TV 연결 준비하기'), findsNothing);
          expect(find.textContaining('확인 번호'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
