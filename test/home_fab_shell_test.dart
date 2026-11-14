import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_list_mode_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_search_screen.dart';
import 'package:image/image.dart' as img;
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_workout_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/home_thumbnail_loader.dart';

import 'home_thumbnail_transport_test.dart' as transport;

import 'support/main_navigation_fixture.dart';
import 'support/ui_layout_evidence.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final scene in [
    (name: '390', size: const Size(390, 844), scale: 1.0),
    (name: '320', size: const Size(320, 568), scale: 1.0),
    (name: '320-large', size: const Size(320, 568), scale: 2.0),
  ]) {
    testWidgets('home FAB clears real dock, scroll and keyboard ${scene.name}', (
      tester,
    ) async {
      await loadLayoutFonts(tester);
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = previousShadows);
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
      addTearDown(tester.view.resetViewInsets);
      final original = await tester.runAsync(
        () =>
            rootBundle.load('assets/slide_templates/stationd_wed_original.png'),
      );
      final thumbnailBytes = img.encodeJpg(
        img.copyResize(
          img.decodePng(original!.buffer.asUint8List())!,
          width: 192,
        ),
        quality: 72,
      );
      final source = transport.legacySource(owner: previewUser.id);
      final requests = <http.Request>[];
      final loader = HomeThumbnailLoader(
        previewUser.id,
        usageFactory: () => transport.fixtureUsage(owner: previewUser.id),
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            thumbnailBytes,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );
      final cache = HomeThumbnailCache(loader.load);
      addTearDown(() {
        cache.dispose();
        loader.dispose();
      });
      final data = NavigationPreviewData(
        active: false,
        count: 6,
        imageSource: source,
        preparationOverrides: [
          homeThumbnailCacheProvider(previewUser.id).overrideWithValue(cache),
        ],
      );
      addTearDown(data.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: data.container,
          child: RepaintBoundary(
            key: const ValueKey('home-shell-evidence'),
            child: MainNavigationPreview(textScale: scene.scale),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, isNotEmpty);
      expect(requests.length, lessThan(6));
      expect(
        data.container.read(homeWorkoutLayoutProvider),
        HomeWorkoutLayout.grid,
      );
      expect(
        (tester
                    .widget<SliverGrid>(
                      find.byKey(const ValueKey('workout-grid')),
                    )
                    .gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        scene.size.width == 390 && scene.scale == 1 ? 2 : 1,
      );
      final fab = find.byKey(const ValueKey('create-workout'));
      final dock = find.byKey(const ValueKey('main-navigation-dock'));
      expect(fab.hitTestable(), findsOneWidget);
      expect(tester.getSize(fab), const Size(56, 56));
      expect(tester.getRect(fab).bottom, lessThan(tester.getRect(dock).top));
      expect(
        tester.getRect(dock).bottom,
        lessThanOrEqualTo(scene.size.height - 34),
      );
      Future<void> resolveThumbnails() async {
        // Mock HTTP completion and native image codecs use separate event-loop
        // turns. Wait for bytes, then for decoded frames before screenshotting.
        for (
          var frame = 0;
          frame < 8 && find.byIcon(Icons.image_outlined).evaluate().isNotEmpty;
          frame++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          final images = find.descendant(
            of: find.byType(HomeWorkoutThumbnail),
            matching: find.byType(Image),
          );
          for (final image in tester.widgetList<Image>(images)) {
            await tester.runAsync(
              () => precacheImage(
                image.image,
                tester.element(fab),
                onError: (error, stack) => fail('Thumbnail codec: $error'),
              ),
            );
          }
          await tester.pumpAndSettle();
        }
        expect(find.byIcon(Icons.image_outlined), findsNothing);
      }

      await resolveThumbnails();
      final initialFab = tester.getRect(fab);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('home-shell-evidence')),
        'shell-${scene.name}',
      );
      expect(
        find.descendant(
          of: find.byType(HomeWorkoutThumbnail),
          matching: find.byType(Image),
        ),
        findsWidgets,
      );
      final scrolling = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('workout-scroll')),
          )
          .controller!;
      scrolling.jumpTo(256);

      await tester.pumpAndSettle();
      expect(tester.getRect(fab), initialFab);
      expect(find.byType(HomeWorkoutThumbnail), findsWidgets);
      await resolveThumbnails();
      await captureLayout(
        tester,
        find.byKey(const ValueKey('home-shell-evidence')),
        'grid-${scene.name}-scrolled',
      );
      // The same account cache survives the subtree swap; only newly visible
      // workout identities may request a rendition.
      scrolling.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-layout-list')));
      await tester.pumpAndSettle();
      scrolling.jumpTo(
        256.clamp(0, scrolling.position.maxScrollExtent).toDouble(),
      );
      await tester.pumpAndSettle();
      await resolveThumbnails();
      expect(
        data.container.read(homeWorkoutLayoutProvider),
        HomeWorkoutLayout.list,
      );
      await captureLayout(
        tester,
        find.byKey(const ValueKey('home-shell-evidence')),
        'list-${scene.name}-scrolled',
      );
      final requestIds = requests
          .map((request) => request.url.queryParameters['workoutId'])
          .toList();
      expect(
        requestIds.toSet().length,
        requestIds.length,
        reason: 'Switching views must not redownload a visible identity',
      );
      // A tab revisit uses the same account preference and mounted home state.
      await tester.tap(find.byKey(const ValueKey('main-tab-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await tester.pumpAndSettle();
      expect(
        data.container.read(homeWorkoutLayoutProvider),
        HomeWorkoutLayout.list,
      );
      expect(scrolling.offset, closeTo(256, 1));
      await tester.drag(
        find.byKey(const ValueKey('workout-scroll')),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byTooltip('워크아웃 메뉴').last).bottom,
        lessThan(tester.getRect(fab).top),
      );
      final homeOffset = scrolling.offset;
      await tester.tap(find.byTooltip('검색'));
      await tester.pumpAndSettle();
      expect(fab, findsNothing);
      expect(find.byType(WorkoutSearchScreen), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byType(WorkoutSearchScreen)))
            .uri
            .path,
        '/search',
      );
      expect(dock, findsNothing);
      expect(
        tester
            .widget<shadcn.ShadInput>(find.byType(shadcn.ShadInput))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(shadcn.ShadInput), '토요일');
      await tester.pumpAndSettle();
      expect(find.text('토요일 팀 워크아웃'), findsWidgets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(fab, findsNothing);
      expect(dock, findsNothing);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('home-shell-evidence')),
        'search-${scene.name}-keyboard',
      );
      await tester.tap(find.byTooltip('뒤로'));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(fab.hitTestable(), findsOneWidget);
      expect(GoRouterState.of(tester.element(fab)).uri.path, '/');
      expect(scrolling.offset, closeTo(homeOffset, 1));
      expect(
        data.container.read(homeWorkoutLayoutProvider),
        HomeWorkoutLayout.list,
      );
      final allIds = requests
          .map((request) => request.url.queryParameters['workoutId'])
          .toList();
      expect(
        allIds.toSet().length,
        allIds.length,
        reason: 'Tab/search revisits reuse cached source revisions',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDisableShadows = previousShadows;
    });
  }
}
