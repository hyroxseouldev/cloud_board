import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';

import 'support/workout_catalog_fixture.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _workout = Workout.empty(
  'workout',
  const WorkoutAuthor(id: 'coach', displayName: 'Coach', photoUrl: null),
).copyWith(name: '스테이션 D', brandL: 'CloudBoard', brandR: 'Station D');

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  for (final width in [320.0, 834.0, 1200.0]) {
    testWidgets('long template chips scroll independently of add at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fixtureWorkoutDetails,
            workoutControllerProvider.overrideWith(_LongWorkouts.new),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            slideTemplatesControllerProvider('coach')
                .overrideWith(_ManyTemplates.new),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: const WorkoutEditorScreen(workoutId: 'workout'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final plus = find.byTooltip('슬라이드 추가');
      final position = tester.getRect(plus);
      final list = find.byKey(const ValueKey('workout-slide-list'));
      final before = tester.widget<ReorderableListView>(list).itemCount;
      final chips = find.byKey(const ValueKey('workout-slide-templates'));
      await tester.drag(chips, const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(plus), position);
      expect(tester.widget<ReorderableListView>(list).itemCount, before);
      await tester.tap(find.byType(InputChip).hitTestable().first);
      await tester.pumpAndSettle();
      expect(tester.widget<ReorderableListView>(list).itemCount, before + 1);
      expect(find.text('라이브러리에서 찾기'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('저장'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('계정 공통 설정은 워크아웃 편집 메뉴에서 제거된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                id: 'coach',
                email: 'coach@example.com',
                displayName: 'Coach',
                photoUrl: null,
              ),
            ),
          ),
          fixtureWorkoutDetails,
          workoutControllerProvider.overrideWith(_TestWorkouts.new),
        ],
        child: const MaterialApp(
          home: WorkoutEditorScreen(workoutId: 'workout'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('화면·사운드 설정'), findsNothing);
    expect(find.text('화면 왼쪽 아래 문구'), findsNothing);
    expect(find.text('수업 사운드'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('header stays fixed and chips and extended FAB add slides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fixtureWorkoutDetails,
          workoutControllerProvider.overrideWith(_LongWorkouts.new),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: WorkoutEditorScreen(workoutId: 'workout'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = tester.getTopLeft(find.text('워크아웃 편집'));
    final list = find.byKey(const ValueKey('workout-slide-list'));
    await tester.drag(list, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('워크아웃 편집')), header);
    expect(find.byTooltip('저장').hitTestable(), findsOneWidget);
    await tester.drag(list, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FloatingActionButton, '슬라이드 추가').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('휴식 60초'), findsNothing);
    expect(find.byTooltip('슬라이드 추가'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('자주 쓰는 슬라이드로 저장'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '칩 이름'),
      '나의 워밍업',
    );
    await tester.tap(find.text('칩 만들기'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(InputChip, '나의 워밍업');
    expect(chip, findsOneWidget);
    await tester.tap(find.text('나의 워밍업'));
    await tester.pumpAndSettle();
    expect(tester.widget<ReorderableListView>(list).itemCount, 13);
    expect(
      find.widgetWithText(ListTile, '나의 워밍업').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('슬라이드 추가'));
    await tester.pumpAndSettle();
    expect(tester.widget<ReorderableListView>(list).itemCount, 14);
    expect(find.text('새 운동 1').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('나의 워밍업 칩 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(tester.widget<ReorderableListView>(list).itemCount, 14);
    expect(tester.getTopLeft(find.text('워크아웃 편집')), header);
    expect(tester.takeException(), isNull);
  });
}

class _TestWorkouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() async* {
    yield [_workout];
  }
}

class _LongWorkouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() async* {
    yield [
      _workout.copyWith(
        modules: List.generate(
          12,
          (i) =>
              WorkoutModule.empty('module-$i')
                  .copyWith(name: '슬라이드 ${i + 1}', workSeconds: 60, sets: 1),
        ),
      ),
    ];
  }
}

class _ManyTemplates extends SlideTemplatesController {
  @override
  Future<List<WorkoutModule>> build(String scope) async => List.generate(
    12,
    (i) =>
        WorkoutModule.empty('template-$i')
            .copyWith(name: '긴 이름의 워밍업 슬라이드 반복 운동 $i'),
  );
}
