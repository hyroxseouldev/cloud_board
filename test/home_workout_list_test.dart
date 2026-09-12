import 'package:cloud_board/src/app/core/theme/app_theme.dart';

import 'dart:async';

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
  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(1194, 834),
  ]) {
    testWidgets('pagination and filters stay consistent at $size', (
      tester,
    ) async {
      final repository = _CatalogRepository(_catalog(25));
      final container = await _mount(tester, repository, size: size);
      int cardCount() => tester
          .widget<GridView>(find.byKey(const ValueKey('workout-grid')))
          .childrenDelegate
          .estimatedChildCount!;
      expect(find.text('1 / 3'), findsOneWidget);
      expect(cardCount(), 13);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('워크아웃 추가')).dx,
        lessThan(tester.getTopLeft(find.text('수업 01')).dx),
      );
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('workout-grid')),
      );
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        size.shortestSide >= 600 ? 3 : 2,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '이전 페이지',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.drag(
        find.byKey(const ValueKey('workout-grid')),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '다음 페이지',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('수업 13').hitTestable(), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '다음 페이지',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(cardCount(), 2);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '다음 페이지',
              ),
            )
            .onPressed,
        isNull,
      );

      // Removing the only row on the last page clamps to the preceding page.
      container.read(workoutControllerProvider.notifier).remove('w25');
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(cardCount(), 13);
      await tester.enterText(find.byType(TextField), '수업 01');
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(cardCount(), 2);
      await tester.tap(find.byTooltip('검색 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '다음 페이지',
        ),
      );
      await tester.pumpAndSettle();
      await _folder(tester, 'Stationd');
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('워크아웃 13개'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '수업 14');
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);
      await tester.tap(find.byTooltip('검색 지우기'));
      await tester.pumpAndSettle();
      await _folder(tester, '다른 폴더');
      expect(find.text('워크아웃 11개'), findsOneWidget);
      for (var i = 14; i <= 24; i++) {
        container.read(workoutControllerProvider.notifier).remove('w$i');
      }
      await tester.pumpAndSettle();
      // The selected folder disappeared; all remaining workouts are reachable.
      expect(find.text('모든 폴더'), findsOneWidget);
      expect(find.text('워크아웃 13개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('refresh waits for all pages and retains the active filter', (
    tester,
  ) async {
    final repository = _CatalogRepository(_catalog(13));
    await _mount(tester, repository);
    await _folder(tester, 'Stationd');
    await tester.enterText(find.byType(TextField), '수업');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '다음 페이지',
      ),
    );
    await tester.pumpAndSettle();
    repository.gate = Completer<void>();
    repository.server = [
      ...repository.cached,
      _catalog(14).last.copyWith(folder: 'Stationd'),
    ];
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '워크아웃 새로고침',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.loads, 2);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('워크아웃 13개'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '워크아웃 새로고침',
            ),
          )
          .onPressed,
      isNull,
    );
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('워크아웃 14개'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Stationd'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '수업',
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '워크아웃 새로고침',
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final emptyCatalog in [true, false]) {
    testWidgets(
      'pull refresh works for ${emptyCatalog ? 'empty catalog' : 'zero search results'}',
      (tester) async {
        final repository = _CatalogRepository(emptyCatalog ? [] : _catalog(1));
        await _mount(tester, repository);
        if (!emptyCatalog) {
          await tester.enterText(find.byType(TextField), '없는 수업');
          await tester.pumpAndSettle();
        }
        await tester.drag(
          find.byKey(const ValueKey('workout-empty-scroll')),
          const Offset(0, 320),
        );
        await tester.pumpAndSettle();
        expect(repository.loads, 2);
        expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed reload offers retry and can recover', (tester) async {
    final repository = _CatalogRepository(_catalog(1));
    await _mount(tester, repository);
    repository.fail = true;
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '워크아웃 새로고침',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('새로고침하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('수업 01'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(repository.loads, 3);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _folder(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _CatalogRepository repository, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
      child: MaterialApp(
        theme: XonTheme.light,
        builder: XonTheme.responsiveBuilder,
        home: const WorkoutListScreen(),
      ),
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
