import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_list_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('fast first response never flashes skeletons or a zero count', (
    tester,
  ) async {
    final repository = ControlledHomeCatalog();
    await mountLoadingHome(tester, repository);
    expect(find.text('워크아웃'), findsOneWidget);
    expect(find.text('워크아웃 0개'), findsNothing);
    expect(find.text('아직 워크아웃이 없어요'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WorkoutListSkeleton), findsNothing);
    repository.respond(0, homeCatalog());
    await tester.pumpAndSettle();
    expect(find.text('수업 1'), findsOneWidget);
    expect(find.text('워크아웃 2개'), findsOneWidget);
    expect(find.byType(WorkoutListSkeleton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'slow first load shows one accessible skeleton and locks folders',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final repository = ControlledHomeCatalog();
        await mountLoadingHome(tester, repository);
        await tester.pump(const Duration(milliseconds: 151));
        expect(find.byType(WorkoutListSkeleton), findsOneWidget);
        expect(find.bySemanticsLabel('워크아웃을 불러오는 중'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('워크아웃 0개'), findsNothing);
        expect(find.byTooltip('재생'), findsNothing);
        await tester.tap(find.byTooltip('폴더 선택'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(repository.requests, hasLength(1));
        expect(find.byType(CheckedPopupMenuItem<String>), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        expect(find.bySemanticsLabel('연결이 조금 지연되고 있어요'), findsOneWidget);
        expect(find.bySemanticsLabel('워크아웃을 불러오는 중'), findsNothing);
        repository.respond(0, homeCatalog());
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutListSkeleton), findsNothing);
        expect(find.text('수업 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('a genuine empty response is distinct from loading', (
    tester,
  ) async {
    final repository = ControlledHomeCatalog();
    await mountLoadingHome(tester, repository);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('아직 워크아웃이 없어요'), findsNothing);
    repository.respond(0, []);
    await tester.pumpAndSettle();
    expect(find.text('워크아웃 0개'), findsOneWidget);
    expect(find.text('아직 워크아웃이 없어요'), findsOneWidget);
    expect(find.byType(WorkoutListSkeleton), findsNothing);
  });

  testWidgets(
    'initial error has one safe retry and retry restores the skeleton',
    (tester) async {
      final repository = ControlledHomeCatalog();
      await mountLoadingHome(tester, repository);
      repository.requests.first.addError(
        StateError('internal diagnostic payload'),
      );
      await tester.pumpAndSettle();
      expect(find.text('워크아웃을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('internal diagnostic payload'), findsNothing);
      expect(find.text('워크아웃 0개'), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byKey(const ValueKey('workout-load-more')), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 151));
      expect(repository.requests, hasLength(2));
      expect(find.byType(WorkoutListSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repository.respond(1, homeCatalog());
      await tester.pumpAndSettle();
      expect(find.text('수업 1'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh preserves the list, scroll position and filter control',
    (tester) async {
      final repository = ControlledHomeCatalog();
      await mountLoadingHome(tester, repository);
      repository.respond(0, homeCatalog(24));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('workout-list'));
      final before = tester.element(list);
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('workout-scroll')),
          )
          .controller!;
      scroll.jumpTo(400);
      await tester.pump();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repository.requests, hasLength(2));
      expect(tester.element(list), same(before));
      expect(scroll.offset, 400);
      expect(find.byType(WorkoutListSkeleton), findsNothing);
      expect(find.byKey(const ValueKey('workout-load-more')), findsNothing);
      repository.respond(1, homeCatalog(24));
      await refresh;
      await tester.pumpAndSettle();
      expect(scroll.offset, 400);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pagination keeps existing rows and has only a footer spinner', (
    tester,
  ) async {
    final repository = ControlledHomeCatalog();
    final container = await mountLoadingHome(tester, repository);
    repository.respond(0, homeCatalog(24), complete: false);
    await tester.pumpAndSettle();
    final next = container.read(workoutControllerProvider.notifier).loadMore();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WorkoutListSkeleton), findsNothing);
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('수업 1'), findsOneWidget);
    repository.respond(0, homeCatalog(25));
    await next;
    await tester.pumpAndSettle();
    expect(find.text('워크아웃 25개'), findsOneWidget);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(402, 874), 1.0),
    (const Size(834, 1194), 2.0),
    (const Size(1194, 834), 1.0),
  ]) {
    testWidgets(
      'static reduced-motion skeleton fits $size at text scale $scale',
      (tester) async {
        final repository = ControlledHomeCatalog();
        await mountLoadingHome(
          tester,
          repository,
          size: size,
          textScale: scale,
          reducedMotion: true,
        );
        await tester.pump(const Duration(milliseconds: 151));
        await tester.pump();
        expect(find.byType(WorkoutListSkeleton), findsOneWidget);
        expect(find.byType(ShaderMask), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
        repository.respond(0, homeCatalog());
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutListSkeleton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'leaving home cancels pending skeleton and delayed-status timers',
    (tester) async {
      await mountLoadingHome(tester, ControlledHomeCatalog());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}

Future<ProviderContainer> mountLoadingHome(
  WidgetTester tester,
  ControlledHomeCatalog repository, {
  Size size = const Size(402, 874),
  double textScale = 1,
  bool reducedMotion = false,
  GlobalKey? captureKey,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: ProviderScope(
        overrides: [
          firstClassControllerProvider.overrideWith(NoFirstClass.new),
          displayDevicesProvider.overrideWith((_) => Stream.value([])),
          activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
          authStateProvider.overrideWith(
            (_) => Stream.value(
              const AuthUser(
                id: 'u',
                email: '',
                displayName: '김선명',
                photoUrl: null,
              ),
            ),
          ),
          loadWorkoutsProvider.overrideWith(
            (_) async => LoadWorkouts(repository),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
              padding: padding,
            ),
            child: XonTheme.responsiveBuilder(context, child),
          ),
          home: const WorkoutListScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(WorkoutListScreen)),
  );
}

class ControlledHomeCatalog implements WorkoutRepository, PagedWorkoutCatalog {
  final requests = <StreamController<WorkoutCatalogPage>>[];

  @override
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false}) {
    final request = StreamController<WorkoutCatalogPage>();
    requests.add(request);
    return request.stream;
  }

  void respond(
    int request,
    List<WorkoutSummary> items, {
    bool complete = true,
  }) {
    requests[request].add(WorkoutCatalogPage(items, complete: complete));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<WorkoutSummary> homeCatalog([int count = 2]) => List.generate(
  count,
  (i) => summarizeWorkout(
    Workout.empty(
      'w$i',
      const WorkoutAuthor(id: 'u', displayName: '김선명', photoUrl: null),
    ).copyWith(
      name: '수업 ${i + 1}',
      updatedAt: DateTime(2026, 10, 9).subtract(Duration(minutes: i)),
    ),
  ),
);

class NoFirstClass extends FirstClassController {
  @override
  Future<FirstClassProgress?> build() async => null;
}
