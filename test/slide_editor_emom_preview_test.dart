import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/timer_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'timer_editor_test.dart' as timer;

WorkoutModule _emom({bool showTimer = false}) => editEmom(
  WorkoutModule.empty('emom-preview').copyWith(
    name: 'EMOM 수업',
    text: '운동 내용 유지',
    timerMode: WorkoutTimerMode.emom,
    showTimer: showTimer,
    showSets: true,
    beep: false,
  ),
  (
    seconds: 60,
    intervals: 5,
    rounds: 10,
    restSeconds: 0,
    includeFinalRest: false,
  ),
);

final _preview = find.byType(WorkoutSlidePreview);
Finder get _previewCanvas =>
    find.descendant(of: _preview, matching: find.byType(WorkoutSlideCanvas));

WorkoutSlideCanvas _canvas(WidgetTester tester) =>
    tester.widget<WorkoutSlideCanvas>(_previewCanvas);

void _expectPreview(
  WidgetTester tester,
  WorkoutModule module,
  String label,
  String total,
) {
  expect(_canvas(tester).module, module);
  expect(_canvas(tester).positionLabel, label);
  expect(
    tester
        .widget<Text>(
          find.descendant(
            of: _preview,
            matching: find.byKey(const ValueKey('slide-sets')),
          ),
        )
        .data,
    label,
  );
  expect(
    tester.widget<Text>(find.byKey(const ValueKey('slide-timer-total'))).data,
    total,
  );
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  WorkoutModule module, {
  Future<bool> Function(WorkoutModule)? save,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        slideEditorRepositoryProvider.overrideWithValue(
          LocalSlideEditorRepository(SlideEditorLocalDataSource()),
        ),
      ],
      child: MaterialApp(
        theme: XonTheme.light,
        builder: XonTheme.responsiveBuilder,
        home: SlideEditorScreen(
          workoutId: 'emom-workout',
          moduleId: module.id,
          guard: ExitGuard(),
          request: SlideEditRequest(
            module: module,
            onSave: save ?? (_) async => true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SlideEditorScreen)),
  );
}

Future<void> _close(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

// The current timer sheet applies its first block. Exercise its existing
// selection callback too, without inventing a separate selection UI.
Future<void> _selectBlock(WidgetTester tester, String id) async {
  await timer.tap(tester, 'slide-timer-summary');
  tester
      .widget<TimerEditorScreen>(find.byType(TimerEditorScreen))
      .onSelectBlock(id);
  await timer.tap(tester, 'close-timer-editor');
}

void main() {
  for (final showTimer in [false, true]) {
    testWidgets('editor preserves five EMOM intervals, showTimer=$showTimer', (
      tester,
    ) async {
      final module = _emom(showTimer: showTimer);
      await _open(tester, module);
      _expectPreview(tester, module, '라운드 1/10 · 구간 1/5', '50:00');
      expect(_canvas(tester).secondsLeft, 60);
      expect(
        find.descendant(
          of: _preview,
          matching: find.byKey(const ValueKey('slide-timer')),
        ),
        showTimer ? findsOneWidget : findsNothing,
      );
      await _close(tester);
    });
  }

  testWidgets('unsaved 5 to 3 to 1 edits, validation, save and reopen agree', (
    tester,
  ) async {
    final original = _emom();
    final saved = <WorkoutModule>[];
    final container = await _open(
      tester,
      original,
      save: (module) async {
        saved.add(module);
        return true;
      },
    );
    final provider = slideEditorControllerProvider(
      'emom-workout',
      original,
      'local',
    );
    _expectPreview(tester, original, '라운드 1/10 · 구간 1/5', '50:00');
    for (final count in [3, 1]) {
      await timer.tap(tester, 'slide-timer-summary');
      final before = container.read(provider).module;
      await timer.input(tester, 'timer-intervals', '0');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('apply-timer-editor')),
            )
            .onPressed,
        isNull,
      );
      expect(container.read(provider).module, before);
      await timer.input(tester, 'timer-intervals', '$count');
      await timer.tap(tester, 'apply-timer-editor');
      final module = container.read(provider).module;
      _expectPreview(
        tester,
        module,
        '라운드 1/10 · 구간 1/$count',
        '${count * 10}:00',
      );
      expect(module.intervalBlocks, hasLength(count));
      expect(module.rounds, 10);
      expect(module.text, original.text);
      expect(module.imageSource, original.imageSource);
      expect(workoutModuleDuration(module), count * 600);
      expect(
        find.byKey(const ValueKey('timer-unsaved-status')),
        findsOneWidget,
      );
      expect(saved, isEmpty);
    }
    await timer.tap(tester, 'slide-save-button');
    expect(saved, hasLength(1));
    expect(container.read(provider).dirty, isFalse);
    final restored = WorkoutModuleModel.fromJson(
      WorkoutModuleModel.fromEntity(saved.single).toJson(),
    ).toEntity();
    await _close(tester);
    await _open(tester, restored);
    _expectPreview(tester, restored, '라운드 1/10 · 구간 1/1', '10:00');
    expect(find.byKey(const ValueKey('timer-unsaved-status')), findsNothing);
    await _close(tester);
  });

  testWidgets(
    'selected interval retains its position and removed IDs fall back',
    (tester) async {
      final original = _emom();
      final container = await _open(tester, original);
      final provider = slideEditorControllerProvider(
        'emom-workout',
        original,
        'local',
      );
      await _selectBlock(tester, original.intervalBlocks.last.id);
      _expectPreview(tester, original, '라운드 1/10 · 구간 5/5', '50:00');
      final reduced = editEmom(original, (
        seconds: 60,
        intervals: 3,
        rounds: 10,
        restSeconds: 0,
        includeFinalRest: false,
      ));
      container.read(provider.notifier).update(reduced);
      await tester.pumpAndSettle();
      _expectPreview(tester, reduced, '라운드 1/10 · 구간 1/3', '30:00');
      await _selectBlock(tester, reduced.intervalBlocks[1].id);
      _expectPreview(tester, reduced, '라운드 1/10 · 구간 2/3', '30:00');
      await _close(tester);
    },
  );

  for (final rounds in [1, 2]) {
    testWidgets(
      'selected repeated work and rest-only blocks keep context ($rounds rounds)',
      (tester) async {
        final module = WorkoutModule.empty('mixed').copyWith(
          name: '여러 구간',
          showSets: true,
          rounds: rounds,
          roundRestSeconds: rounds == 1 ? 0 : 25,
          includeFinalRoundRest: false,
          intervalBlocks: const [
            WorkoutIntervalBlock(
              id: 'a',
              workSeconds: 30,
              restSeconds: 10,
              sets: 2,
            ),
            WorkoutIntervalBlock(
              id: 'b',
              workSeconds: 45,
              restSeconds: 15,
              sets: 3,
            ),
            WorkoutIntervalBlock(
              id: 'c',
              workSeconds: 0,
              restSeconds: 20,
              sets: 2,
            ),
          ],
        );
        await _open(tester, module);
        await _selectBlock(tester, 'b');
        expect(_canvas(tester).module, module);
        expect(_canvas(tester).secondsLeft, 45);
        expect(_canvas(tester).set, 1);
        expect(_canvas(tester).totalSets, 3);
        expect(
          _canvas(tester).positionLabel,
          rounds == 1 ? null : '라운드 1/2 · 구간 3/7',
        );
        await _selectBlock(tester, 'c');
        expect(_canvas(tester).module, module);
        expect(_canvas(tester).isRest, isTrue);
        expect(_canvas(tester).secondsLeft, 20);
        expect(_canvas(tester).totalSets, 2);
        expect(
          _canvas(tester).positionLabel,
          rounds == 1 ? '휴식 1/2' : '라운드 1/2 · 휴식',
        );
        await _close(tester);
      },
    );
  }

  testWidgets('editor rehearsal and player keep all fifty minute phases', (
    tester,
  ) async {
    final module = _emom();
    final container = await _open(tester, module);
    await timer.tap(tester, 'slide-preview-rehearse');
    expect(
      tester
          .widget<SlideRehearsalScreen>(find.byType(SlideRehearsalScreen))
          .module,
      module,
    );
    final actions = container.read(
      slideRehearsalControllerProvider(module).notifier,
    );
    expect(actions.totalMs, 3000000);
    for (var index = 0; index < 6; index++) {
      actions.seek(index * 60000);
      await tester.pump();
      final canvas = tester.widget<WorkoutSlideCanvas>(
        find.byType(WorkoutSlideCanvas),
      );
      expect(
        canvas.positionLabel,
        '라운드 ${index ~/ 5 + 1}/10 · 구간 ${index % 5 + 1}/5',
      );
    }
    final workout = Workout.empty(
      'preview-workout',
      const WorkoutAuthor(id: 'local', displayName: 'Local', photoUrl: null),
    ).copyWith(countdownSeconds: 0, modules: [module]);
    final steps = buildPlayerSteps(workout);
    expect(steps, hasLength(50));
    expect(steps.fold<int>(0, (sum, step) => sum + step.duration), 3000);
    expect(steps[4].positionLabel, '라운드 1/10 · 구간 5/5');
    expect(steps[5].positionLabel, '라운드 2/10 · 구간 1/5');
    await tester.pageBack();
    await tester.pumpAndSettle();
    _expectPreview(tester, module, '라운드 1/10 · 구간 1/5', '50:00');
    await _close(tester);
  });
}
