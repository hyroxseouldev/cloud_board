import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_list_card.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/workout_catalog_fixture.dart';

const _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
final _workout =
    Workout.empty(
      'workout',
      const WorkoutAuthor(id: 'coach', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: '10/9 수업',
      modules: [
        WorkoutModule.empty('wave').copyWith(
          name: 'WAVE ZONE (CASH OUT)',
          designTemplate: 'studio-v1-numbered',
          designBackgroundColor: 0xFFFFFFFF,
          designAccentColor: 0xFFFF6200,
          text: 'Run 250m\nSki 250m\nWallball 30',
          workSeconds: 800,
          restSeconds: 60,
          showTimer: false,
          showSets: false,
        ),
        WorkoutModule.empty('race').copyWith(
          name: 'RACE ZONE',
          imageSource: _pixel,
          workSeconds: 800,
          restSeconds: 60,
        ),
        WorkoutModule.empty('timer').copyWith(name: '마무리 타이머'),
      ],
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (834.0, 1.0),
    (390.0, 2.0),
  ]) {
    testWidgets('slide content and controls share one row at $width / $scale', (
      tester,
    ) async {
      await _pumpEditor(tester, width: width, scale: scale);
      final card = find.byKey(const ValueKey('wave'));
      final preview = find.descendant(
        of: card,
        matching: find.byType(WorkoutSlidePreview),
      );
      final handle = find.byKey(const ValueKey('slide-drag-wave'));
      final menu = find.descendant(
        of: card,
        matching: find.byTooltip('슬라이드 메뉴'),
      );
      expect(
        tester.getCenter(handle).dy,
        closeTo(tester.getCenter(preview).dy, 1),
      );
      expect(
        tester.getCenter(menu).dy,
        closeTo(tester.getCenter(preview).dy, 1),
      );
      expect(
        tester.getRect(handle).right,
        lessThanOrEqualTo(tester.getRect(preview).left),
      );
      expect(
        tester.getRect(preview).right,
        lessThan(tester.getRect(find.text('WAVE ZONE (CASH OUT)')).left),
      );
      expect(
        tester.widget<WorkoutSlidePreview>(preview).module,
        _workout.modules.first,
      );
      expect(
        tester
            .widget<ReorderableDragStartListener>(
              find.byKey(const ValueKey('slide-drag-wave')),
            )
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dragging the handle reorders previews and persists the order', (
    tester,
  ) async {
    final saved = <Workout>[];
    await _pumpEditor(tester, saved: saved);
    final first = find.byKey(const ValueKey('slide-drag-wave'));
    final next = find.byKey(const ValueKey('slide-drag-race'));
    final distance = tester.getCenter(next) - tester.getCenter(first);
    final drag = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 100));
    for (var step = 0; step < 12; step++) {
      await drag.moveBy(distance / 12);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 250));
    await drag.up();
    await tester.pumpAndSettle();
    final cards = tester.widgetList<WorkoutSlideListCard>(
      find.byType(WorkoutSlideListCard),
    );
    expect(cards.map((card) => card.module.id), ['race', 'wave', 'timer']);
    expect(
      tester
          .widget<ReorderableDragStartListener>(
            find.byKey(const ValueKey('slide-drag-wave')),
          )
          .index,
      1,
    );
    expect(saved, isEmpty);
    await tester.tap(find.byKey(const ValueKey('workout-save-button')));
    await tester.pumpAndSettle();
    expect(saved.single.modules.map((module) => module.id), [
      'race',
      'wave',
      'timer',
    ]);
    expect(saved.single.modules.first.imageSource, _pixel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image taps edit the slide and its menu can still duplicate', (
    tester,
  ) async {
    final router = await _pumpEditor(tester);
    final image = find.descendant(
      of: find.byKey(const ValueKey('race')),
      matching: find.byType(WorkoutImage),
    );
    expect(tester.widget<WorkoutImage>(image).source, _pixel);
    await tester.tap(find.byTooltip('슬라이드 메뉴').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('복제'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/editor/workout');
    final cards = tester.widgetList<WorkoutSlideListCard>(
      find.byType(WorkoutSlideListCard),
    );
    expect(cards.take(2).map((card) => card.module.designTemplate), [
      'studio-v1-numbered',
      'studio-v1-numbered',
    ]);
    final preview = find.descendant(
      of: find.byKey(const ValueKey('wave')),
      matching: find.byType(WorkoutSlidePreview),
    );
    await tester.tapAt(tester.getCenter(preview));
    await tester.pumpAndSettle();
    expect(find.text('슬라이드 편집'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, height, scale) in [
    (320.0, 568.0, 1.0),
    (844.0, 390.0, 1.0),
    (834.0, 1194.0, 1.0),
    (390.0, 844.0, 2.0),
  ]) {
    testWidgets(
      'blank creation opens its editor and saves back to the list at $width / $scale',
      (tester) async {
        final saved = <Workout>[];
        SlideEditRequest? opened;
        final router = await _pumpEditor(
          tester,
          width: width,
          height: height,
          scale: scale,
          saved: saved,
          onEdit: (request) => opened = request,
        );
        final list = find.byKey(const ValueKey('workout-slide-list'));
        await _openCreationSheet(tester);
        expect(find.text('빈 슬라이드 추가'), findsOneWidget);
        expect(find.text('템플릿·AI로 만들기'), findsOneWidget);
        expect(tester.widget<ReorderableListView>(list).itemCount, 3);
        final design = find.byKey(const ValueKey('create-slide-design'));
        await tester.ensureVisible(design);
        await tester.pumpAndSettle();
        expect(design.hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.byType(CloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.widget<ReorderableListView>(list).itemCount, 3);

        await _openCreationSheet(tester);
        final blank = find.byKey(const ValueKey('create-slide-blank'));
        await tester.ensureVisible(blank);
        await tester.pumpAndSettle();
        await tester.tap(blank);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('슬라이드 편집'), findsOneWidget);
        final request = opened!;
        expect(request.module.name, '새 운동 1');
        expect(request.module.imageSource, isEmpty);
        expect(request.needsInitialSave, isTrue);
        expect(request.workout!.modules, hasLength(4));
        expect(request.workout!.modules.last.id, request.module.id);
        expect(saved, isEmpty);
        expect(await request.onSave(request.module), isTrue);
        await tester.pumpAndSettle();
        expect(saved.single.modules.last, request.module);
        router.pop();
        await tester.pumpAndSettle();
        expect(tester.widget<ReorderableListView>(list).itemCount, 4);
        final added = tester
            .widgetList<WorkoutSlideListCard>(find.byType(WorkoutSlideListCard))
            .singleWhere((card) => card.module.name == '새 운동 1');
        expect(added.module.imageSource, isEmpty);
        expect(added.selected, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'design creation only appends slides after the editor returns them',
    (tester) async {
      final saved = <Workout>[];
      final router = await _pumpEditor(tester, saved: saved);
      final list = find.byKey(const ValueKey('workout-slide-list'));
      await _openCreationSheet(tester);
      await tester.tap(find.byKey(const ValueKey('create-slide-design')));
      await tester.pumpAndSettle();
      expect(find.text('이미지 슬라이드 추가'), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<ReorderableListView>(list).itemCount, 3);

      await _openCreationSheet(tester);
      await tester.tap(find.byKey(const ValueKey('create-slide-design')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이미지 슬라이드 추가'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/editor/workout');
      expect(tester.widget<ReorderableListView>(list).itemCount, 4);
      final added = tester.widget<WorkoutSlideListCard>(
        find.byKey(const ValueKey('created-image')),
      );
      expect(added.module.imageSource, _pixel);
      expect(added.selected, isTrue);
      expect(saved, isEmpty);
      await tester.tap(find.byKey(const ValueKey('workout-save-button')));
      await tester.pumpAndSettle();
      expect(saved.single.modules.last.id, 'created-image');
      expect(saved.single.modules.last.imageSource, _pixel);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openCreationSheet(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('add-slide-at-end'));
  await tester.scrollUntilVisible(
    button,
    400,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('workout-slide-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpEditor(
  WidgetTester tester, {
  double width = 390,
  double height = 1000,
  double scale = 1,
  List<Workout>? saved,
  ValueChanged<SlideEditRequest>? onEdit,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/editor/workout',
    routes: [
      GoRoute(
        path: '/editor/:id',
        builder: (_, _) => const WorkoutEditorScreen(workoutId: 'workout'),
        routes: [
          GoRoute(
            path: 'slides/:moduleId',
            builder: (_, state) {
              onEdit?.call(state.extra as SlideEditRequest);
              return const Scaffold(body: Text('슬라이드 편집'));
            },
          ),
          GoRoute(
            path: 'images/create',
            builder: (context, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => context.pop([
                    WorkoutModule.empty('created-image')
                        .copyWith(name: '템플릿 슬라이드', imageSource: _pixel),
                  ]),
                  child: const Text('이미지 슬라이드 추가'),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        fixtureWorkoutDetails,
        workoutControllerProvider.overrideWith(_Workouts.new),
        workoutActionControllerProvider.overrideWith(() => _Save(saved ?? [])),
        slideEditorRepositoryProvider.overrideWithValue(
          LocalSlideEditorRepository(SlideEditorLocalDataSource()),
        ),
      ],
      child: MaterialApp.router(
        theme: XonTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _Workouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value([_workout]);
}

class _Save extends WorkoutActionController {
  _Save(this.saved);
  final List<Workout> saved;
  @override
  Future<Workout?> save(Workout workout) async {
    saved.add(workout);
    return workout;
  }
}
