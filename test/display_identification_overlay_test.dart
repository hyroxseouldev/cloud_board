import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_identification_overlay.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/audience_branding_fixture.dart'
    show audiencePumpUntil, audienceSession;
import 'support/display_identification_fixture.dart';

const codeKey = ValueKey('display-identification-code');

void main() {
  for (final size in [
    const Size(1280, 720),
    const Size(1920, 1080),
    const Size(3840, 2160),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'isolated overlay owns rendered styles and fits long name at $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: XonTheme.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: const DefaultTextStyle(
                  // Match the sentinel style exposed by a missing Material ancestor.
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 48,
                    fontFamily: 'monospace',
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.yellow,
                    decorationStyle: TextDecorationStyle.double,
                  ),
                  child: DisplayIdentificationOverlay(
                    deviceName: identificationLongName,
                    code: '0584',
                  ),
                ),
              ),
            ),
          );
          final surface = tester.widget<Material>(
            find.byKey(const ValueKey('display-identification-surface')),
          );
          expect(surface.color, AppColors.canvas);
          for (final widget in tester.widgetList<RichText>(
            find.descendant(
              of: find.byType(DisplayIdentificationOverlay),
              matching: find.byType(RichText),
            ),
          )) {
            // Icon fonts intentionally differ; inspect every rendered text span.
            final style = widget.text.style!;
            if (style.fontFamily == 'MaterialIcons') continue;
            expect(
              style.color,
              anyOf(AppColors.ink, AppColors.muted, AppColors.accent),
            );
            expect(style.fontFamily, 'Pretendard');
            expect(style.decoration, TextDecoration.none);
            expect(style.decorationColor, isNot(Colors.yellow));
            expect(style.fontWeight, isNot(FontWeight.w700));
          }
          final content = tester.getRect(
            find.byKey(const ValueKey('display-identification-content')),
          );
          expect(content.left, greaterThanOrEqualTo(size.width * .05 - .01));
          expect(content.right, lessThanOrEqualTo(size.width * .95 + .01));
          expect(content.top, greaterThanOrEqualTo(size.height * .05 - .01));
          expect(content.bottom, lessThanOrEqualTo(size.height * .95 + .01));
          Rect renderedRect(Finder finder) {
            final box = tester.renderObject<RenderBox>(finder);
            return MatrixUtils.transformRect(
              box.getTransformTo(null),
              Offset.zero & box.size,
            );
          }

          final number = renderedRect(find.byKey(codeKey));
          final name = renderedRect(
            find.byKey(const ValueKey('display-identification-name')),
          );
          final hint = tester.getRect(find.text('관리 기기에서 이 번호를 확인해 주세요.'));
          expect(number.overlaps(name), isFalse);
          expect(number.overlaps(hint), isFalse);
          expect(tester.widget<Text>(find.byKey(codeKey)).data, '0584');
          expect(find.text(identificationLongName), findsOneWidget);
          expect(find.text('연결 완료'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final device in [
    ('tv-a', '메인 디스플레이', '0584'),
    ('tv-b', '북쪽 스튜디오', '2196'),
    ('tv-c', '3층 스트레칭 공간', '8740'),
  ]) {
    testWidgets(
      'actual display ${device.$1} renders its own name/code and silently ACKs',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = IdentificationFixture(tester, deviceId: device.$1);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app());
        await tester.pump();
        fixture.start([
          identificationDevice('tv-a', '메인 디스플레이', 'nonce-0584'),
          identificationDevice('tv-b', '북쪽 스튜디오', 'nonce-2196'),
          identificationDevice('tv-c', '3층 스트레칭 공간', 'nonce-8740'),
        ]);
        await audiencePumpUntil(
          tester,
          () =>
              find.byType(DisplayIdentificationOverlay).evaluate().length == 1,
          'identification visible',
        );
        await tester.pump();
        expect(find.text(device.$2), findsOneWidget);
        expect(find.byType(StoreWelcomeBoard), findsNothing);
        expect(tester.widget<Text>(find.byKey(codeKey)).data, device.$3);
        expect(fixture.actions.acknowledgements, [
          '${device.$1}:nonce-${device.$3}',
        ]);
        expect(fixture.sound.calls, 0);
        // Explicitly cleared requests restore the existing center standby view.
        fixture.devices.add([
          identificationDevice(
            device.$1,
            device.$2,
            'nonce-${device.$3}',
            expiresAtMs: 0,
          ),
        ]);
        await audiencePumpUntil(
          tester,
          () => find.byType(DisplayIdentificationOverlay).evaluate().isEmpty,
          'expired identification removed',
        );
        expect(find.byType(StoreWelcomeBoard), findsOneWidget);
        expect(fixture.sound.calls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await fixture.dispose();
      },
    );
  }

  testWidgets(
    'server-time expiry, active class and offline state prevent stale identification and ACK',
    (tester) async {
      final fixture = IdentificationFixture(tester);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app());
      await tester.pump();
      fixture.start([
        identificationDevice(
          'tv',
          '메인 TV',
          'nonce-0584',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 10000,
        ),
      ]);
      await audiencePumpUntil(
        tester,
        () => find.byType(DisplayIdentificationOverlay).evaluate().isNotEmpty,
        'identification visible',
      );
      await tester.pump();
      expect(fixture.actions.acknowledgements, ['tv:nonce-0584']);
      expect(fixture.sound.calls, 0);
      fixture.offset.add(20000);
      await audiencePumpUntil(
        tester,
        () => find.byType(DisplayIdentificationOverlay).evaluate().isEmpty,
        'server expiry hides request',
      );
      fixture.offset.add(0);
      fixture.sessions.add(audienceSession(tester));
      fixture.devices.add([identificationDevice('tv', '메인 TV', 'nonce-9999')]);
      await audiencePumpUntil(
        tester,
        () => find.byType(WorkoutSlideCanvas).evaluate().isNotEmpty,
        'active class visible',
      );
      expect(find.byType(DisplayIdentificationOverlay), findsNothing);
      expect(fixture.actions.acknowledgements, ['tv:nonce-0584']);
      fixture.connection.add(false);
      fixture.sessions.add(null);
      fixture.devices.add([identificationDevice('tv', '메인 TV', 'nonce-7777')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(DisplayIdentificationOverlay), findsNothing);
      expect(fixture.actions.acknowledgements, ['tv:nonce-0584']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );
}
