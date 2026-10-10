import 'package:cloud_board/src/app/core/widgets/motion/app_animated_sliver_list.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_list_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets(
    'scroll loads the next page and search finds the last unrequested page',
    (tester) async {
      final repo = _PagedCatalogRepository(_catalog(60));
      final container = await _mount(tester, repo);
      expect(repo.loads, 1);
      expect(container.read(workoutControllerProvider).requireValue.length, 24);
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('workout-scroll')),
          )
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(container.read(workoutControllerProvider).requireValue.length, 48);
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), '수업 60');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repo.loads, 3);
      expect(container.read(workoutControllerProvider).requireValue.length, 60);
      expect(_title('수업 60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mode selector is hidden by default but can enable both browsing modes',
    (tester) async {
      final container = await _mount(tester, _CatalogRepository(_catalog(25)));
      expect(find.byTooltip('목록 표시 방식'), findsNothing);
      expect(
        find.byKey(const ValueKey('workout-page-indicator')),
        findsNothing,
      );
      expect(
        container.read(workoutListModeControllerProvider),
        WorkoutListMode.continuous,
      );
      await tester.pumpWidget(const SizedBox.shrink());

      await _mount(
        tester,
        _CatalogRepository(_catalog(25)),
        showModeSelector: true,
      );
      await tester.tap(find.byTooltip('목록 표시 방식'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('페이지 넘기기'),
          matching: find.byType(CheckedPopupMenuItem<WorkoutListMode>),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        tester
            .widget<AppAnimatedSliverList<WorkoutSummary>>(
              find.byKey(const ValueKey('workout-list')),
            )
            .items
            .length,
        12,
      );
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('목록 표시 방식'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('무한 스크롤'),
          matching: find.byType(CheckedPopupMenuItem<WorkoutListMode>),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workout-page-indicator')),
        findsNothing,
      );
      expect(
        tester
            .widget<AppAnimatedSliverList<WorkoutSummary>>(
              find.byKey(const ValueKey('workout-list')),
            )
            .items
            .length,
        25,
      );
      expect(_title('수업 01').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(834, 1194)]) {
    testWidgets(
      'paged browsing restores search, resets filters, clamps deleted pages and refreshes at $size',
      (tester) async {
        final repository = _CatalogRepository(_catalog(25));
        final container = await _mount(tester, repository, size: size);
        container
            .read(workoutListModeControllerProvider.notifier)
            .select(WorkoutListMode.paged);
        await tester.pumpAndSettle();
        expect(find.byTooltip('목록 표시 방식'), findsNothing);
        expect(find.text('1 / 3'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '이전 페이지',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('다음 페이지'));
        await tester.pumpAndSettle();
        expect(_title('수업 13').hitTestable(), findsOneWidget);
        await _openSearch(tester);
        await tester.enterText(find.byType(TextField), '수업 25');
        await tester.pumpAndSettle();
        expect(find.text('1 / 1'), findsOneWidget);
        expect(_title('수업 25'), findsOneWidget);
        await tester.tap(find.byTooltip('검색 닫기'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 3'), findsOneWidget);
        expect(_title('수업 13').hitTestable(), findsOneWidget);
        await _folder(tester, 'Stationd');
        expect(find.text('1 / 2'), findsOneWidget);
        await tester.tap(find.byTooltip('다음 페이지'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '다음 페이지',
                ),
              )
              .onPressed,
          isNull,
        );
        container.read(workoutControllerProvider.notifier).remove('w13');
        await tester.pumpAndSettle();
        expect(find.text('1 / 1'), findsOneWidget);
        container
            .read(workoutControllerProvider.notifier)
            .upsert(_catalog(13).last);
        await tester.pumpAndSettle();
        expect(find.text('1 / 2'), findsOneWidget);
        await tester.tap(find.byTooltip('다음 페이지'));
        await tester.pumpAndSettle();
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        await refresh;
        expect(find.text('2 / 2'), findsOneWidget);
        expect(repository.loads, 2);
        expect(find.text('Stationd'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('drawer closes before navigating and stays closed on return', (
    tester,
  ) async {
    await _mount(
      tester,
      _CatalogRepository(_catalog(1)),
      testProfileRoute: true,
    );
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('슬라이드 라이브러리'), findsNothing);
    await tester.tap(find.text('라이브러리'));
    await tester.pump();
    // Navigation must not cover and mute the still-closing drawer.
    expect(find.text('라이브러리: all'), findsNothing);
    expect(find.byType(Drawer), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('라이브러리: all'), findsOneWidget);
    expect(find.byType(Drawer, skipOffstage: false), findsNothing);
    GoRouter.of(tester.element(find.text('라이브러리: all'))).pop();
    await tester.pump();
    expect(find.byType(Drawer, skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byTooltip('메뉴').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 목적지'), findsOneWidget);
    expect(find.byType(Drawer, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing search restores folder and continuous scroll position', (
    tester,
  ) async {
    await _mount(tester, _CatalogRepository(_catalog(25)));
    await _folder(tester, 'Stationd');
    await tester.scrollUntilVisible(
      _title('수업 13'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    final scroll = find.byKey(const ValueKey('workout-scroll'));
    final before = tester.widget<CustomScrollView>(scroll).controller!.offset;
    expect(before, greaterThan(0));
    await _openSearch(tester);
    await tester.enterText(find.byType(TextField), '수업 01');
    await tester.pumpAndSettle();
    expect(_title('수업 01'), findsOneWidget);
    await tester.tap(find.byTooltip('검색 닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.widget<CustomScrollView>(scroll).controller!.offset,
      closeTo(before, 1),
    );
    expect(_title('수업 13').hitTestable(), findsOneWidget);
    await tester.drag(scroll, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Stationd'), findsOneWidget);
  });

  testWidgets('cards retain bounds and thumbnail ratio as the window resizes', (
    tester,
  ) async {
    for (final (width, columns) in [
      (320.0, 1),
      (390.0, 1),
      (640.0, 1),
      (768.0, 1),
      (834.0, 1),
      (960.0, 1),
      (1600.0, 1),
    ]) {
      await _mount(
        tester,
        _CatalogRepository(_catalog(1)),
        size: Size(width, 1000),
        textScale: 2,
      );
      if (width >= 600) {
        final grid = tester.widget<SliverGrid>(
          find.byKey(const ValueKey('workout-grid')),
        );
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          columns,
        );
      } else {
        expect(find.byKey(const ValueKey('workout-list')), findsOneWidget);
      }
      final thumbnail = tester.getSize(
        find.byKey(const ValueKey('workout-thumbnail-w1')),
      );
      expect(thumbnail.width, lessThanOrEqualTo(72));
      expect(thumbnail.width / thumbnail.height, closeTo(1, .001));
      await tester.ensureVisible(find.byTooltip('재생'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('재생').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('settings profile header opens profile with no duplicate menu', (
    tester,
  ) async {
    await _mount(
      tester,
      _CatalogRepository(_catalog(1)),
      testProfileRoute: true,
    );
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 조회 및 변경'), findsNothing);
    expect(find.text('앱 버전'), findsNothing);
    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 목적지'), findsOneWidget);
  });

  testWidgets('class commands do not flash a page overlay or reset browsing', (
    tester,
  ) async {
    final commands = _Commands();
    await _mount(tester, _CatalogRepository(_catalog(25)), commands: commands);
    await _openSearch(tester);
    await tester.enterText(find.byType(TextField), '수업');
    await tester.drag(
      find.byKey(const ValueKey('workout-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final grid = find.byKey(const ValueKey('workout-scroll'));
    final before = tester.widget<CustomScrollView>(grid).controller!.offset;
    final gridElement = tester.element(grid);
    for (final result in [
      const AsyncData<String?>(null),
      AsyncError<String?>(StateError('offline'), StackTrace.current),
    ]) {
      commands.setStatus(const AsyncLoading());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AbsorbPointer && widget.absorbing,
        ),
        findsNothing,
      );
      expect(tester.element(grid), same(gridElement));
      expect(tester.widget<CustomScrollView>(grid).controller!.offset, before);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '수업',
      );
      commands.setStatus(result);
      await tester.pump();
      expect(tester.element(grid), same(gridElement));
    }
    expect(find.textContaining('수업 제어에 실패했습니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active workout card explains lock; edit/delete disabled and copy allowed',
    (tester) async {
      final workout = _catalog(1).single;
      await _mount(
        tester,
        _CatalogRepository([workout]),
        activeSession: PlaybackSession(
          id: 's',
          ownerId: 'u',
          zoneId: 'main',
          workout: workout,
          status: PlaybackStatus.paused,
          stepIndex: 0,
          remainingMs: 60000,
          anchorServerMs: 0,
          revision: 1,
          updatedByDeviceId: 'controller',
        ),
      );
      await tester.ensureVisible(_title('수업 01'));
      await tester.pumpAndSettle();
      await tester.tap(_title('수업 01'));
      await tester.pumpAndSettle();
      expect(find.text(workoutPlayingEditMessage), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('워크아웃 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('워크아웃 메뉴'));
      await tester.pumpAndSettle();
      PopupMenuItem<dynamic> item(String label) =>
          tester.widget<PopupMenuItem<dynamic>>(
            find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
            ),
          );
      expect(item('편집').enabled, isFalse);
      expect(item('삭제').enabled, isFalse);
      expect(item('복사').enabled, isTrue);
    },
  );

  for (final (size, columns) in [
    (const Size(390, 844), 1),
    (const Size(834, 1194), 1),
    (const Size(1194, 834), 2),
  ]) {
    testWidgets(
      'continuous lazy scrolling reaches every item and retains filters at $size',
      (tester) async {
        final repository = _CatalogRepository(_catalog(60));
        final container = await _mount(tester, repository, size: size);
        final mobile = size.width < 600;
        expect(find.byTooltip('다음 페이지'), findsNothing);
        expect(
          find.byKey(const ValueKey('workout-page-indicator')),
          findsNothing,
        );
        expect(
          _title('수업 60'),
          findsNothing,
        ); // Offscreen rows are not built eagerly.
        if (!mobile) {
          final grid = tester.widget<SliverGrid>(
            find.byKey(const ValueKey('workout-grid')),
          );
          expect(
            (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            columns,
          );
        }
        await tester.scrollUntilVisible(
          _title('수업 60'),
          600,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        expect(_title('수업 60').hitTestable(), findsOneWidget);
        expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
        container.read(workoutControllerProvider.notifier).remove('w60');
        await tester.pumpAndSettle();
        expect(_title('수업 60'), findsNothing);
        await _openSearch(tester);
        await tester.enterText(find.byType(TextField), '수업 59');
        await tester.pumpAndSettle();
        expect(_title('수업 59').hitTestable(), findsOneWidget);
        expect(find.text('워크아웃 1개'), findsOneWidget);
        await tester.tap(find.byTooltip('검색 지우기'));
        await tester.pumpAndSettle();
        await _folder(tester, 'Stationd');
        expect(find.text('워크아웃 13개'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '수업 59');
        await tester.pumpAndSettle();
        expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
        await tester.tap(find.byTooltip('검색 지우기'));
        await tester.pumpAndSettle();
        await _folder(tester, '다른 폴더');
        for (var i = 14; i <= 59; i++) {
          container.read(workoutControllerProvider.notifier).remove('w$i');
        }
        await tester.pumpAndSettle();
        expect(find.text('모든 폴더'), findsOneWidget);
        expect(find.text('워크아웃 13개'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'refresh waits for the server, preserves browsing, and coalesces requests',
    (tester) async {
      final repository = _CatalogRepository(_catalog(13));
      final container = await _mount(tester, repository);
      await _folder(tester, 'Stationd');
      await _openSearch(tester);
      await tester.enterText(find.byType(TextField), '수업');
      await tester.pumpAndSettle();
      final scroll = find.byKey(const ValueKey('workout-scroll'));
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      final before = tester.widget<CustomScrollView>(scroll).controller!.offset;
      final originalElement = tester.element(scroll);
      repository.gate = Completer<void>();
      repository.server = [
        ...repository.cached,
        _catalog(14).last.copyWith(folder: 'Stationd'),
      ];
      final controller = container.read(workoutControllerProvider.notifier);
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      final duplicate = controller.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.loads, 2);
      expect(tester.element(scroll), same(originalElement));
      expect(
        tester.widget<CustomScrollView>(scroll).controller!.offset,
        before,
      );
      repository.gate!.complete();
      await refresh;
      await duplicate;
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '수업',
      );
      expect(
        tester.widget<CustomScrollView>(scroll).controller!.offset,
        before,
      );
      controller.upsert(_catalog(1).single.copyWith(name: '새 제목'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final count in [0, 1]) {
      testWidgets('$kind pull refresh works over the header with $count rows', (
        tester,
      ) async {
        final repository = _CatalogRepository(_catalog(count));
        await _mount(tester, repository);
        // The old fixed header was outside the refresh scrollable.
        final point = tester.getCenter(find.text('워크아웃 $count개'));
        final gesture = await tester.startGesture(point, kind: kind);
        await gesture.moveBy(const Offset(0, 340));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(repository.loads, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('desktop web offers an accessible refresh action', (
    tester,
  ) async {
    if (!kIsWeb) return;
    final repository = _CatalogRepository(_catalog(1));
    await _mount(tester, repository, size: const Size(1280, 800));
    await tester.tap(find.byTooltip('새로고침'));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(tester.takeException(), isNull);
  });

  for (final emptyCatalog in [true, false]) {
    testWidgets(
      'pull refresh works for ${emptyCatalog ? 'empty catalog' : 'zero search results'}',
      (tester) async {
        final repository = _CatalogRepository(emptyCatalog ? [] : _catalog(1));
        await _mount(tester, repository);
        if (!emptyCatalog) {
          await _openSearch(tester);
          await tester.enterText(find.byType(TextField), '없는 수업');
          await tester.pumpAndSettle();
        }
        await tester.drag(
          find.byKey(const ValueKey('workout-scroll')),
          const Offset(0, 320),
        );
        await tester.pumpAndSettle();
        expect(repository.loads, 2);
        expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed reload retains the list and the next pull can recover', (
    tester,
  ) async {
    final repository = _CatalogRepository(_catalog(1));
    await _mount(tester, repository);
    repository.fail = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('새로고침하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(_title('수업 01'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    repository.fail = false;
    await tester.drag(
      find.byKey(const ValueKey('workout-scroll')),
      const Offset(0, 340),
    );
    await tester.pumpAndSettle();
    expect(
      find
          .text('수업 01', findRichText: false)
          .evaluate()
          .where((e) => e.widget is Text)
          .length,
      1,
    );
    expect(find.text('다시 시도'), findsNothing);
    expect(repository.loads, 3);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _folder(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('폴더 선택'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.ancestor(
      of: find.text(name).last,
      matching: find.byType(CheckedPopupMenuItem<String>),
    ),
  );
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _CatalogRepository repository, {
  Size size = const Size(390, 844),
  PlaybackSession? activeSession,
  _Commands? commands,
  bool testProfileRoute = false,
  bool? showModeSelector,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = testProfileRoute
      ? GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const WorkoutListScreen()),
            GoRoute(
              path: '/profile',
              builder: (_, _) => const Scaffold(body: Text('프로필 목적지')),
            ),
            GoRoute(
              path: '/slides',
              builder: (_, state) => Scaffold(
                body: Text(
                  '라이브러리: ${state.uri.queryParameters['favorites'] ?? 'all'}',
                ),
              ),
            ),
          ],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (showModeSelector != null)
          workoutListModeSelectorEnabledProvider.overrideWithValue(
            showModeSelector,
          ),
        displayDevicesProvider.overrideWith((ref) => Stream.value([])),
        if (commands != null)
          playbackActionControllerProvider.overrideWith(() => commands),
        activePlaybackSessionProvider.overrideWith(
          (ref) => Stream.value(activeSession),
        ),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AuthUser(
              id: 'u',
              email: '',
              displayName: 'Coach',
              photoUrl: null,
            ),
          ),
        ),
        loadWorkoutsProvider.overrideWith(
          (ref) async => LoadWorkouts(repository),
        ),
      ],
      child: router == null
          ? MaterialApp(
              theme: XonTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: XonTheme.responsiveBuilder(context, child),
              ),
              home: const WorkoutListScreen(),
            )
          : MaterialApp.router(theme: XonTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(WorkoutListScreen)),
  );
}

List<Workout> _catalog(int count) => List.generate(
  count,
  (index) =>
      Workout.empty(
        'w${index + 1}',
        const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
      ).copyWith(
        name: '수업 ${(index + 1).toString().padLeft(2, '0')}',
        folder: index < 13 ? 'Stationd' : '다른 폴더',
        updatedAt: DateTime(2026, 9, 11).subtract(Duration(minutes: index)),
      ),
);

class _CatalogRepository implements WorkoutRepository {
  _CatalogRepository(this.cached);
  final List<Workout> cached;
  List<Workout>? server;
  Completer<void>? gate;
  bool fail = false;
  int loads = 0;
  @override
  Stream<List<WorkoutSummary>> watchSummaries({bool requireServer = false}) =>
      watch().map((items) => items.map(summarizeWorkout).toList());
  @override
  Future<Workout?> loadOne(String id) async =>
      (server ?? cached).where((w) => w.id == id).firstOrNull;

  @override
  Stream<List<Workout>> watch() async* {
    loads++;
    if (fail) throw StateError('offline');
    yield cached;
    if (gate != null) await gate!.future;
    yield server ?? cached;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Commands extends PlaybackActionController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  void setStatus(AsyncValue<String?> value) => state = value;
}

class _PagedCatalogRepository extends _CatalogRepository
    implements PagedWorkoutCatalog {
  _PagedCatalogRepository(super.cached);
  @override
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false}) async* {
    var offset = 0;
    while (offset < cached.length) {
      loads++;
      offset = (offset + 24).clamp(0, cached.length);
      yield WorkoutCatalogPage(
        cached.take(offset).map(summarizeWorkout).toList(),
        complete: offset == cached.length,
      );
    }
  }
}

Future<void> _openSearch(WidgetTester tester) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('검색'));
    await tester.pumpAndSettle();
  }
}

Finder _title(String text) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == text);
