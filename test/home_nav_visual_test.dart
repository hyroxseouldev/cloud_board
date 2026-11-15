import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_list_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/main_navigation_fixture.dart';
import 'support/ui_layout_evidence.dart';

const baseline = bool.fromEnvironment('HOME_NAV_BASELINE');

void main() {
  for (final scene in [
    (name: '390', size: const Size(390, 844), scale: 1.0, active: false),
    (name: '390-active', size: const Size(390, 844), scale: 1.0, active: true),
    (
      name: '844-landscape',
      size: const Size(844, 390),
      scale: 1.0,
      active: false,
    ),
    (name: '320-text2', size: const Size(320, 568), scale: 2.0, active: false),
  ]) {
    for (final count in [1, 6]) {
      testWidgets(
        'home content and final controls ${scene.name} count=$count',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await loadLayoutFonts(tester);
          final shadows = debugDisableShadows;
          debugDisableShadows = false;
          addTearDown(() => debugDisableShadows = shadows);
          await tester.runAsync(
            () =>
                (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                      rootBundle.load(
                        'packages/lucide_icons_flutter/assets/lucide.ttf',
                      ),
                    ))
                    .load(),
          );
          tester.view.physicalSize = scene.size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(bottom: 34);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final data = NavigationPreviewData(
            active: scene.active,
            count: count,
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: data.container,
              child: RepaintBoundary(
                key: const ValueKey('home-nav-capture'),
                child: MainNavigationPreview(textScale: scene.scale),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            data.container.read(homeWorkoutLayoutProvider),
            HomeWorkoutLayout.grid,
          );
          for (final mode in ['grid', 'list']) {
            final scrollFinder = find.byKey(const ValueKey('workout-scroll'));
            final scroll = tester
                .widget<CustomScrollView>(scrollFinder)
                .controller!;
            if (mode == 'list') {
              scroll.jumpTo(0);
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const ValueKey('home-layout-list')));
              await tester.pumpAndSettle();
            }
            final fab = find.byKey(const ValueKey('create-workout'));
            final dock = find.byKey(const ValueKey('main-navigation-dock'));
            expect(fab.hitTestable(), findsOneWidget);
            expect(tester.getSize(fab).shortestSide, greaterThanOrEqualTo(48));
            expect(
              tester.getRect(fab).bottom,
              lessThan(tester.getRect(dock).top),
            );
            if (!baseline) {
              final homeScaffold = find
                  .ancestor(of: scrollFinder, matching: find.byType(Scaffold))
                  .first;
              expect(
                tester.getRect(scrollFinder).bottom,
                closeTo(tester.getRect(homeScaffold).bottom, .01),
                reason: 'No opaque bottom viewport reservation',
              );
              if (mode == 'grid') {
                for (final item in tester.widgetList<Container>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is Container &&
                        widget.key.toString().contains('workout-grid-card-'),
                  ),
                )) {
                  expect(item.decoration, isNull);
                  expect(item.color, isNull);
                }
              }
            }
            await captureLayout(
              tester,
              find.byKey(const ValueKey('home-nav-capture')),
              '${scene.name}-$count-$mode-top',
            );
            scroll.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            if (!baseline) {
              final play = find.byTooltip('재생').last;
              expect(play.hitTestable(), findsOneWidget);
              expect(
                tester.getRect(play).bottom,
                lessThan(tester.getRect(fab).top),
              );
              final menu = find.byTooltip('워크아웃 메뉴').last;
              expect(menu.hitTestable(), findsOneWidget);
              expect(
                tester.getRect(menu).bottom,
                lessThan(tester.getRect(fab).top),
              );
            }
            await captureLayout(
              tester,
              find.byKey(const ValueKey('home-nav-capture')),
              '${scene.name}-$count-$mode-end',
            );
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          data.dispose();
          await tester.pump();
          debugDisableShadows = shadows;
        },
      );
    }
  }
}
