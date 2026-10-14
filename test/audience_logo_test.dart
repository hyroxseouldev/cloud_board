import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/audience_logo_frame.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

import 'support/audience_branding_fixture.dart';

final logo = find.byKey(const ValueKey('audience-cloudboard-logo'));
final legacyLogo = find.byKey(const ValueKey('standby-cloudboard-logo'));
final reserved = find.byKey(const ValueKey('audience-logo-reserved-area'));

void main() {
  for (final size in [
    const Size(1920, 1080),
    const Size(3840, 2160),
    const Size(1024, 768),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'audience footer stays outside content and within safe area at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final scene in AudienceLogoScene.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: AudienceLogoFrame(
                branding: audienceFree,
                scene: scene,
                preferences: const DisplayPreferences(
                  enabled: true,
                  zoom: 2,
                  offsetX: .2,
                  offsetY: .2,
                  safeInset: .08,
                ),
                child: const ColoredBox(
                  key: ValueKey('audience-content'),
                  color: Colors.white,
                ),
              ),
            ),
          );
          await tester.pump();
          final badge = tester.getRect(logo);
          final content = tester.getRect(
            find.byKey(const ValueKey('audience-content')),
          );
          expect(badge.overlaps(content), isFalse);
          expect(badge.bottom, lessThanOrEqualTo(size.height * .92 + .01));
          expect(badge.left, greaterThanOrEqualTo(size.width * .08));
          expect(badge.right, lessThanOrEqualTo(size.width * .92));
          expect(badge.height, greaterThanOrEqualTo(28));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'standby/countdown/work/rest/pause share one product logo; changes keep the player and timer',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AudienceFixture(tester);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app());
      await tester.pump();
      fixture.start();
      await audiencePumpUntil(
        tester,
        () => logo.evaluate().length == 1,
        'standby logo',
      );
      expect(legacyLogo, findsNothing);
      final workout = audienceWorkout();
      fixture.sessions.add(
        audienceSession(tester, workout: workout, briefing: true),
      );
      await audiencePumpUntil(
        tester,
        () => find.byType(StoreWelcomeBoard).evaluate().isNotEmpty,
        'briefing uses standby',
      );
      expect(logo, findsOneWidget);
      fixture.sessions.add(
        audienceSession(tester, workout: workout, delay: 10000, revision: 2),
      );
      await audiencePumpUntil(
        tester,
        () => find.byType(WorkoutCountdown).evaluate().length == 1,
        'countdown ready',
      );
      expect(logo, findsOneWidget);
      final player = tester.element(find.byType(WorkoutPlayerScreen));
      fixture.sessions.add(
        audienceSession(tester, workout: workout, revision: 3),
      );
      await audiencePumpUntil(
        tester,
        () => find.byType(WorkoutSlideCanvas).evaluate().length == 1,
        'exercise ready',
      );
      final canvas = find.byType(WorkoutSlideCanvas);
      final provider = playerControllerProvider(
        workout,
        sessionId: 'session',
        canControl: false,
      );
      final before = fixture.container.read(provider).remainingMs;
      final bounds = tester.getRect(canvas);
      fixture.setPolicy(
        audienceFree.copyWith(
          showCloudBoardLogo: false,
          revision: 2,
          projectionRevision: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(logo, findsNothing);
      expect(reserved, findsOneWidget);
      expect(tester.getRect(canvas), bounds);
      expect(tester.element(find.byType(WorkoutPlayerScreen)), same(player));
      expect(fixture.container.read(provider).remainingMs, lessThan(before));
      expect(fixture.container.read(provider).isPaused, isFalse);
      fixture.setPolicy(
        audienceFree.copyWith(revision: 3, projectionRevision: 3),
      );
      fixture.sessions.add(
        audienceSession(tester, workout: workout, step: 1, revision: 4),
      );
      await audiencePumpUntil(
        tester,
        () => tester.widget<WorkoutSlideCanvas>(canvas).isRest,
        'rest ready',
      );
      expect(logo, findsOneWidget);
      fixture.sessions.add(
        audienceSession(
          tester,
          workout: workout,
          step: 1,
          paused: true,
          revision: 5,
        ),
      );
      await audiencePumpUntil(
        tester,
        () => tester.widget<WorkoutSlideCanvas>(canvas).isPaused,
        'pause ready',
      );
      expect(logo, findsOneWidget);
      expect(find.text('일시정지'), findsOneWidget);
      expect(tester.element(find.byType(WorkoutPlayerScreen)), same(player));
      fixture.sessions.add(null);
      await audiencePumpUntil(
        tester,
        () => find.byType(StoreWelcomeBoard).evaluate().length == 1,
        'completion returns to standby',
      );
      expect(logo, findsOneWidget);
      expect(legacyLogo, findsNothing);
      fixture.display('black');
      await audiencePumpUntil(
        tester,
        () => logo.evaluate().isEmpty,
        'black removes all branding',
      );
      expect(reserved, findsNothing);
      expect(legacyLogo, findsNothing);
      fixture.setPolicy(audienceFree.copyWith(projectionRevision: 4));
      await tester.pump();
      expect(logo, findsNothing);
      fixture.display('standby');
      await audiencePumpUntil(
        tester,
        () => logo.evaluate().length == 1,
        'output disabled means standby, not black',
      );
      final now = DateTime.now();
      final minute = now.hour * 60 + now.minute;
      fixture.brands.add(
        BrandTemplate.initial().copyWith(
          blackScreenStartMinutes: (minute + 1435) % 1440,
          blackScreenEndMinutes: (minute + 5) % 1440,
        ),
      );
      fixture.display('auto');
      await audiencePumpUntil(
        tester,
        () => logo.evaluate().isEmpty,
        'scheduled black removes branding',
      );
      expect(reserved, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );

  testWidgets(
    'unknown and standby-only policy never add class logos; user text cannot suppress product branding',
    (tester) async {
      final fixture = AudienceFixture(tester, policy: null, isTv: false);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app());
      await tester.pump();
      fixture.start();
      await audiencePumpUntil(
        tester,
        () => find.byType(StoreWelcomeBoard).evaluate().length == 1,
        'standby ready',
      );
      fixture.brands.add(
        BrandTemplate.initial().copyWith(showCloudBoardLogo: true),
      );
      await tester.pump();
      expect(legacyLogo, findsOneWidget);
      expect(logo, findsNothing);
      fixture.setPolicy(
        audienceFree.copyWith(
          scope: AudienceLogoScope.standby,
          showCloudBoardLogo: false,
        ),
      );
      await tester.pump();
      expect(legacyLogo, findsNothing);
      expect(logo, findsNothing);
      final original = audienceWorkout();
      final w = original.copyWith(
        brandL: '',
        brandR: '',
        modules: [
          original.modules.single.copyWith(
            appearance: original.modules.single.appearance.copyWith(
              showBrand: false,
            ),
            coverImage: true,
          ),
        ],
      );
      fixture.sessions.add(audienceSession(tester, workout: w));
      await audiencePumpUntil(
        tester,
        () => find.byType(WorkoutSlideCanvas).evaluate().length == 1,
        'class ready',
      );
      expect(logo, findsNothing);
      expect(reserved, findsNothing);
      fixture.setPolicy(audienceFree);
      await tester.pump();
      expect(logo, findsOneWidget);
      fixture.setPolicy(null);
      await tester.pump();
      expect(logo, findsNothing);
      expect(reserved, findsNothing);
      expect(find.byType(WorkoutSlideCanvas), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );

  testWidgets(
    'uploaded cover image and zoom cannot cover product logo or move it into user content',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = AudienceFixture(
        tester,
        preferences: const DisplayPreferences(
          enabled: true,
          cover: true,
          zoom: 2,
          offsetX: .2,
          offsetY: -.2,
          safeInset: .08,
        ),
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app());
      await tester.pump();
      fixture.start();
      final source = audienceWorkout(image: true);
      final workout = source.copyWith(
        brandL: '',
        brandR: '',
        modules: [
          source.modules.single.copyWith(
            appearance: source.modules.single.appearance.copyWith(
              showBrand: false,
            ),
          ),
        ],
      );
      fixture.sessions.add(audienceSession(tester, workout: workout));
      await audiencePumpUntil(
        tester,
        () => find.byType(WorkoutImage).evaluate().isNotEmpty,
        'image slide ready',
      );
      final decoded = find.descendant(
        of: find.byType(WorkoutImage),
        matching: find.byWidgetPredicate(
          (widget) => widget is RawImage && widget.image != null,
        ),
      );
      // Browser image decoding needs real event-loop turns between Flutter
      // frames; waiting only for precacheImage can deadlock its fake clock.
      for (var frame = 0; frame < 60 && decoded.evaluate().isEmpty; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(decoded, findsOneWidget);
      expect(logo, findsOneWidget);
      final badge = tester.getRect(logo);
      expect(
        badge.overlaps(tester.getRect(find.byType(WorkoutSlideCanvas))),
        isFalse,
      );
      expect(badge.bottom, lessThanOrEqualTo(1080 * .92 + .01));
      expect(
        tester
            .widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas))
            .module
            .imageSource,
        audienceImage,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    },
  );

  testWidgets('coach countdown remains outside audience logo benefit', (
    tester,
  ) async {
    final fixture = AudienceFixture(tester);
    addTearDown(fixture.dispose);
    final w = audienceWorkout();
    await tester.pumpWidget(
      fixture.app(
        screen: WorkoutPlayerScreen(
          workoutId: w.id,
          startModule: 0,
          sessionId: 'session',
        ),
      ),
    );
    await tester.pump();
    fixture.start();
    fixture.sessions.add(audienceSession(tester, workout: w, delay: 10000));
    await audiencePumpUntil(
      tester,
      () => find.byType(WorkoutCountdown).evaluate().length == 1,
      'coach countdown',
    );
    expect(logo, findsNothing);
    expect(reserved, findsNothing);
    expect(find.byKey(const ValueKey('pause-countdown')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await fixture.dispose();
  });
}
