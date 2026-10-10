import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/main_navigation_fixture.dart';

void main() {
  navigationTest(
    'tab switches preserve both searches, category and home scroll',
    (tester) async {
      final data = await mountNavigation(tester, active: false, count: 30);
      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'HYROX');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.drag(
        find.byKey(const ValueKey('workout-scroll')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('workout-scroll')),
          )
          .controller!;
      final offset = scroll.offset;
      final homeElement = tester.element(
        find.byKey(const ValueKey('workout-scroll')),
      );
      await selectTab(tester, 'library');
      expect(
        find.byKey(const ValueKey('library-category-tabs')),
        findsOneWidget,
      );
      await tester.tap(find.text('워크아웃').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '토요일');
      FocusManager.instance.primaryFocus?.unfocus();
      await selectTab(tester, 'displays');
      await selectTab(tester, 'more');
      await selectTab(tester, 'home');
      expect(
        tester.element(find.byKey(const ValueKey('workout-scroll'))),
        same(homeElement),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'HYROX',
      );
      expect(scroll.offset, closeTo(offset, 1));
      await selectTab(tester, 'home');
      expect(scroll.offset, closeTo(offset, 1));
      await selectTab(tester, 'library');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '토요일',
      );
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      expect(data.repository.loads, 1);
      expect(data.commands.transports, 0);
    },
  );

  navigationTest(
    'session appearing, tab switching and ending never remount home or send commands',
    (tester) async {
      final data = await mountNavigation(tester, active: false);
      final homeElement = tester.element(
        find.byKey(const ValueKey('workout-scroll')),
      );
      data.setSession(navigationSession(data.repository.items.first));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey('workout-scroll'))),
        same(homeElement),
      );
      final session = data.session!;
      final player = playerControllerProvider(
        session.workout,
        sessionId: session.id,
      );
      final controller = data.container.read(player.notifier);
      final remaining = data.container.read(player).remainingMs;
      for (final tab in ['library', 'displays', 'more', 'home']) {
        await selectTab(tester, tab);
        expect(find.byKey(const ValueKey('mini-class-bar')), findsOneWidget);
        expect(data.container.read(player.notifier), same(controller));
        expect(data.container.read(player).remainingMs, remaining);
      }
      expect(data.commands.transports, 0);
      await tester.tap(find.byTooltip('수업 재개'));
      await tester.pumpAndSettle();
      expect(data.commands.transports, 1);
      await tester.tap(find.byTooltip('수업 일시정지'));
      await tester.pumpAndSettle();
      expect(data.commands.transports, 2);
      data.setSession(session.copyWith(status: PlaybackStatus.completed));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mini-class-bar')), findsNothing);
      expect(
        tester.element(find.byKey(const ValueKey('workout-scroll'))),
        same(homeElement),
      );
    },
  );

  navigationTest(
    'real editor hides the dock and returns to its original home',
    (tester) async {
      final data = await mountNavigation(tester, active: false);
      await tester.tap(find.byKey(const ValueKey('create-workout')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutEditorScreen), findsOneWidget);
      expect(find.byType(MainNavigationDock), findsNothing);
      data.container.read(appRouterProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create-workout')), findsOneWidget);
      expect(find.byType(MainNavigationDock), findsOneWidget);
    },
  );

  navigationTest(
    'deep links select their root and system back from another tab returns home',
    (tester) async {
      final data = await mountNavigation(tester, active: false);
      final router = data.container.read(appRouterProvider);
      for (final destination in MainDestination.values.skip(1)) {
        router.go(destination.path);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MainNavigationDock>(find.byType(MainNavigationDock))
              .selected,
          destination,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
    },
  );

  navigationTest('account switch clears mounted tab filters', (tester) async {
    final data = await mountNavigation(tester, active: false);
    await selectTab(tester, 'library');
    await tester.enterText(find.byType(TextField), '다른 계정에 남으면 안 됨');
    FocusManager.instance.primaryFocus?.unfocus();
    await selectTab(tester, 'more');
    data.users.add(
      previewUser.copyWith(id: 'another-account', displayName: '새 코치'),
    );
    await tester.pumpAndSettle();
    await selectTab(tester, 'library');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(834, 1194), 1.0),
    (const Size(1440, 900), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    navigationTest(
      'dock, mini player, safe area and keyboard at $size text $scale',
      (tester) async {
        await mountNavigation(tester, size: size, textScale: scale);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        await tester.pumpAndSettle();
        final dock = find.byKey(const ValueKey('main-navigation-dock'));
        final mini = find.byKey(const ValueKey('mini-class-bar'));
        expect(tester.getRect(mini).bottom, lessThan(tester.getRect(dock).top));
        expect(tester.getRect(dock).bottom, closeTo(size.height - 24 - 16, 1));
        expect(
          tester.getRect(find.byKey(const ValueKey('workout-scroll'))).bottom,
          lessThan(tester.getRect(mini).top),
        );
        final semantics = tester.ensureSemantics();
        for (final destination in MainDestination.values) {
          final tab = find.byKey(ValueKey('main-tab-${destination.name}'));
          expect(tester.getSize(tab).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
          final node = tester.getSemantics(
            find.bySemanticsLabel(destination.label),
          );
          expect(
            node.getSemanticsData().flagsCollection.isSelected ==
                Tristate.isTrue,
            destination == MainDestination.home,
          );
        }
        semantics.dispose();
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        await tester.pumpAndSettle();
        expect(dock, findsNothing);
        expect(mini, findsNothing);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(dock, findsOneWidget);
        await selectTab(tester, 'library');
        await selectTab(tester, 'more');
        expect(tester.takeException(), isNull);
      },
    );
  }

  navigationTest(
    'controller navigation hides when the device switches to display mode',
    (tester) async {
      final data = await mountNavigation(tester, active: false);
      // More has no display bootstrap, so this isolates the shell's mode policy.
      await selectTab(tester, 'more');
      await data.container
          .read(deviceModeControllerProvider.notifier)
          .setMode(DeviceMode.display);
      await tester.pump();
      expect(find.byType(MainNavigationDock), findsNothing);
    },
  );
}

Future<void> selectTab(WidgetTester tester, String tab) async {
  await tester.tap(find.byKey(ValueKey('main-tab-$tab')));
  await tester.pumpAndSettle();
}

Future<NavigationPreviewData> mountNavigation(
  WidgetTester tester, {
  bool active = true,
  int count = 3,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.view.resetPadding);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/wakelock'),
    (_) async => null,
  );
  final data = NavigationPreviewData(active: active, count: count);
  _mountedData.add(data);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: data.container,
      child: MainNavigationPreview(textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
  return data;
}

final _mountedData = <NavigationPreviewData>[];
void navigationTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final data in _mountedData) {
        data.dispose();
      }
      _mountedData.clear();
      await tester.pump();
    }
  });
}
