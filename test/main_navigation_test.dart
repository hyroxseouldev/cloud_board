import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_list_mode_controller.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

import 'support/main_navigation_fixture.dart';
import 'support/ui_layout_evidence.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('dock destinations match exact roots only', () {
    for (final destination in MainDestination.values) {
      expect(MainDestination.forPath(destination.path), destination);
    }
    for (final path in [
      '/editor/new',
      '/workouts/id/prepare',
      '/player/id',
      '/slides/detail',
      '/displays/id',
      '/more/help',
      '/unknown',
    ]) {
      expect(MainDestination.forPath(path), isNull);
    }
  });

  testWidgets('keyboard focus and activation dispatch only explicit actions', (
    tester,
  ) async {
    final selections = <MainDestination>[];
    final semantics = tester.ensureSemantics();
    Future<void> mount(MainDestination selected) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainNavigationDock(
            selected: selected,
            onSelected: selections.add,
          ),
        ),
      ),
    );
    await mount(MainDestination.home);
    expect(selections, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final home = tester.getSemantics(find.bySemanticsLabel('홈'));
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<InkWell>()
          ?.key,
      const ValueKey('main-tab-home'),
    );
    expect(home.getSemanticsData().flagsCollection.isButton, isTrue);
    // The restored Material dock uses InkWell's native focus/activation.
    expect(
      tester.widget(find.byKey(const ValueKey('main-tab-home'))),
      isA<InkWell>(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections, [MainDestination.home]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(selections, [MainDestination.home, MainDestination.library]);
    await mount(MainDestination.library);
    await tester.pumpAndSettle();
    expect(
      selections.length,
      2,
    ); // Selection rebuild never triggers navigation.
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('라이브러리'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final accessible in [false, true]) {
    testWidgets(
      'dock respects reduced motion and still selects immediately: accessible=$accessible',
      (tester) async {
        MainDestination? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: !accessible,
                accessibleNavigation: accessible,
              ),
              child: Scaffold(
                bottomNavigationBar: MainNavigationDock(
                  selected: MainDestination.home,
                  onSelected: (value) => selected = value,
                ),
              ),
            ),
          ),
        );
        for (final pill in tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        )) {
          expect(pill.duration, Duration.zero);
        }
        await tester.tap(find.byKey(const ValueKey('main-tab-library')));
        expect(selected, MainDestination.library);
        expect(tester.takeException(), isNull);
      },
    );
  }

  navigationTest(
    'search page returns to home state and tab switches preserve library search and category',
    (tester) async {
      final data = await mountNavigation(tester, active: false, count: 30);
      await tester.tap(find.byKey(const ValueKey('home-layout-list')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('폴더 선택'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(shad.ShadOption<String>),
          matching: find.text('Stationd'),
        ),
      );
      await tester.pumpAndSettle();
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
      expect(offset, greaterThan(0));
      final homeElement = tester.element(
        find.byKey(const ValueKey('workout-scroll')),
      );

      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(tester.element(find.byType(EditableText))).uri.path,
        '/search',
      );
      expect(find.byType(MainNavigationDock), findsNothing);
      expect(find.byKey(const ValueKey('create-workout')), findsNothing);
      expect(find.text('모든 폴더'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'HYROX');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'HYROX',
      );
      expect(find.text('내 수업 10개'), findsOneWidget);
      final searchScroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('workout-scroll')),
          )
          .controller!;
      expect(searchScroll, isNot(same(scroll)));
      await tester.drag(
        find.byKey(const ValueKey('workout-scroll')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(searchScroll.offset, greaterThan(0));
      expect(scroll.offset, closeTo(offset, 1));
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();

      Future<void> expectHomeState() async {
        expect(
          tester.element(find.byKey(const ValueKey('workout-scroll'))),
          same(homeElement),
        );
        expect(find.byType(EditableText), findsNothing);
        expect(scroll.offset, closeTo(offset, 1));
        expect(
          data.container.read(homeWorkoutLayoutProvider),
          HomeWorkoutLayout.list,
        );
        // Reveal the lazy header to assert its retained folder, then return to
        // the original offset before the next navigation transition.
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(shad.ShadSelect<String>),
            matching: find.text('Stationd'),
          ),
          findsOneWidget,
        );
        expect(find.text('내 수업 15개'), findsOneWidget);
        scroll.jumpTo(offset);
        await tester.pumpAndSettle();
      }

      expect(find.byType(MainNavigationDock), findsOneWidget);
      await expectHomeState();
      await selectTab(tester, 'library');
      expect(
        find.byKey(const ValueKey('library-category-tabs')),
        findsOneWidget,
      );
      await tester.tap(find.text('워크아웃').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '토요일');
      FocusManager.instance.primaryFocus?.unfocus();
      await selectTab(tester, 'displays');
      await selectTab(tester, 'more');
      await selectTab(tester, 'home');
      await expectHomeState();
      await selectTab(tester, 'home');
      expect(scroll.offset, closeTo(offset, 1));
      await selectTab(tester, 'library');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '토요일',
      );
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      expect(data.repository.loads, 1);
      expect(data.commands.transports, 0);
      expect(tester.takeException(), isNull);
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
    'more keeps first-class help without the retired exploration entry',
    (tester) async {
      final data = await mountNavigation(tester, active: false);
      final router = data.container.read(appRouterProvider);
      router.go('/more');
      await tester.pumpAndSettle();
      expect(find.text('예시 수업 둘러보기'), findsNothing);
      await tester.ensureVisible(find.text('첫 수업 준비'));
      await tester.tap(find.text('첫 수업 준비'));
      await tester.pumpAndSettle();
      expect(find.byType(FirstClassScreen), findsOneWidget);
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
    await tester.enterText(find.byType(EditableText), '다른 계정에 남으면 안 됨');
    FocusManager.instance.primaryFocus?.unfocus();
    await selectTab(tester, 'more');
    data.users.add(
      previewUser.copyWith(id: 'another-account', displayName: '새 코치'),
    );
    await tester.pumpAndSettle();
    await selectTab(tester, 'library');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
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
        await loadLayoutFonts(tester);
        await tester.runAsync(
          () =>
              (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                    rootBundle.load(
                      'packages/lucide_icons_flutter/assets/lucide.ttf',
                    ),
                  ))
                  .load(),
        );
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = previousShadows);
        final captureKey = GlobalKey();
        await mountNavigation(
          tester,
          size: size,
          textScale: scale,
          captureKey: captureKey,
        );
        tester.view.padding = const FakeViewPadding(bottom: 24);
        await tester.pumpAndSettle();
        final dock = find.byKey(const ValueKey('main-navigation-dock'));
        final mini = find.byKey(const ValueKey('mini-class-bar'));
        await captureLayout(
          tester,
          find.byKey(captureKey),
          'active-home-${size.width.toInt()}x${size.height.toInt()}-text$scale',
        );
        final fab = find.byKey(const ValueKey('create-workout'));
        expect(fab.hitTestable(), findsOneWidget);
        // The existing responsive theme enlarges the FAB on tablet/desktop.
        expect(tester.getSize(fab).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(fab).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(fab).bottom, lessThan(tester.getRect(mini).top));
        expect(tester.getRect(mini).bottom, lessThan(tester.getRect(dock).top));
        expect(tester.getRect(dock).bottom, closeTo(size.height - 24 - 16, 1));
        expect(
          tester.getRect(find.byKey(const ValueKey('workout-scroll'))).bottom,
          lessThan(tester.getRect(mini).top),
        );
        if (size.height <= 450 || (size.width == 320 && scale == 2)) {
          // The persistent controls must leave a visible class to browse even
          // before scrolling on short screens and with enlarged system text.
          expect(tester.getSize(mini).height, lessThanOrEqualTo(64));
          final row = find
              .ancestor(
                of: find.byKey(const ValueKey('workout-thumbnail-preview-0')),
                matching: find.byType(InkWell),
              )
              .first;
          expect(row, findsOneWidget);
          final viewport = tester.getRect(
            find.byKey(const ValueKey('workout-scroll')),
          );
          expect(tester.getRect(row).top, lessThan(viewport.bottom));
          expect(find.byTooltip('수업 재개').hitTestable(), findsOneWidget);
          expect(find.byTooltip('수업으로 돌아가기').hitTestable(), findsOneWidget);
        }
        final scroll = tester
            .widget<CustomScrollView>(
              find.byKey(const ValueKey('workout-scroll')),
            )
            .controller!;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        for (final action in ['재생', '워크아웃 메뉴']) {
          final last = find.byTooltip(action).last;
          expect(last.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(last).bottom,
            lessThan(tester.getRect(fab).top),
          );
        }
        await captureLayout(
          tester,
          find.byKey(captureKey),
          'active-home-${size.width.toInt()}x${size.height.toInt()}-text$scale-scrolled',
        );
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
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
        debugDisableShadows = previousShadows;
      },
    );
  }

  navigationTest(
    'single class actions remain reachable above FAB in both layouts',
    (tester) async {
      for (final scene in [
        (const Size(390, 844), 1.0),
        (const Size(844, 390), 1.0),
        (const Size(320, 568), 2.0),
      ]) {
        await mountNavigation(
          tester,
          active: false,
          count: 1,
          size: scene.$1,
          textScale: scene.$2,
        );
        final scroll = tester
            .widget<CustomScrollView>(
              find.byKey(const ValueKey('workout-scroll')),
            )
            .controller!;
        for (final layout in ['grid', 'list']) {
          scroll.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('home-layout-$layout')));
          await tester.pumpAndSettle();
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          final fab = find.byKey(const ValueKey('create-workout'));
          expect(fab.hitTestable(), findsOneWidget);
          for (final action in ['재생', '워크아웃 메뉴']) {
            final button = find.byTooltip(action);
            expect(button.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(button).bottom,
              lessThan(tester.getRect(fab).top),
            );
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

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
  GlobalKey? captureKey,
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
    RepaintBoundary(
      key: captureKey,
      child: UncontrolledProviderScope(
        container: data.container,
        child: MainNavigationPreview(textScale: textScale),
      ),
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
