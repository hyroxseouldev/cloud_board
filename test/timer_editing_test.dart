import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/timer_editor_controller.dart';

void main() {
  final source = WorkoutModule.empty('draft').copyWith(
    name: 'WAVE ZONE',
    text: '기존 운동 내용',
    showTimer: false,
    workSeconds: 800,
    restSeconds: 60,
  );
  final emom = editEmom(source, (
    seconds: 120,
    intervals: 3,
    rounds: 6,
    restSeconds: 30,
    includeFinalRest: true,
  ));
  final custom = source.copyWith(
    rounds: 3,
    roundRestSeconds: 40,
    intervalBlocks: const [
      WorkoutIntervalBlock(id: 'a', workSeconds: 70, restSeconds: 20, sets: 2),
      WorkoutIntervalBlock(id: 'b', workSeconds: 0, restSeconds: 30, sets: 1),
      WorkoutIntervalBlock(id: 'c', workSeconds: 120, restSeconds: 0, sets: 3),
    ],
  );

  test('opening, switching detail view and entering identical values preserve legacy data', () {
    for (final initial in [
      source.copyWith(timingVersion: 1),
      source,
      emom,
      custom,
    ]) {
      final container = ProviderContainer();
      final provider = timerEditorControllerProvider(initial);
      final subscription = container.listen(provider, (_, _) {});
      final actions = container.read(provider.notifier);
      expect(container.read(provider).module, initial);
      actions.showDetails(true);
      final b = effectiveIntervalBlocks(initial).first;
      actions.setInput('work', formatSlideTime(b.workSeconds), blockId: b.id);
      actions.setInput('rest', formatSlideTime(b.restSeconds), blockId: b.id);
      actions.setInput('repeats', '${b.sets}', blockId: b.id);
      actions.setFinalRest(initial.includeFinalRest);
      expect(container.read(provider).module, initial);
      expect(actions.dirty, isFalse);
      subscription.close();
      container.dispose();
    }
  });

  test(
    'EMOM expansion keeps old identities and allocates unique block ids',
    () {
      final expanded = editEmom(emom, (
        seconds: 120,
        intervals: 8,
        rounds: 6,
        restSeconds: 30,
        includeFinalRest: true,
      ));
      expect(expanded.intervalBlocks.take(3), emom.intervalBlocks);
      expect(expanded.intervalBlocks.map((b) => b.id).toSet(), hasLength(8));
      expect(timingValidationError(expanded), isNull);
      expect(expanded.name, source.name);
      expect(expanded.text, source.text);
      expect(expanded.showTimer, isFalse);
    },
  );

  test('compatible custom EMOM conversion preserves the entire sequence', () {
    final legacy = createEmom(source, (
      seconds: 95,
      intervals: 4,
      rounds: 7,
      restSeconds: 35,
      includeFinalRest: false,
    ));
    final converted = timerModeCandidate(legacy, WorkoutTimerMode.emom);
    expect(converted.timerMode, WorkoutTimerMode.emom);
    expect(converted.intervalBlocks, legacy.intervalBlocks);
    expect(converted.rounds, 7);
    expect(converted.roundRestSeconds, 35);
    expect(converted.includeFinalRoundRest, isFalse);
    expect(workoutModuleDuration(converted), workoutModuleDuration(legacy));
  });

  test('detailed edits keep compatible modes and only downgrade incompatible structures', () {
    final preserved = editTimerBlocks(emom, [
      for (final b in emom.intervalBlocks) b.copyWith(workSeconds: 60),
    ]);
    expect(preserved.timerMode, WorkoutTimerMode.emom);
    final changed = editTimerBlocks(emom, [
      emom.intervalBlocks.first.copyWith(workSeconds: 61),
      ...emom.intervalBlocks.skip(1),
    ]);
    expect(changed.timerMode, WorkoutTimerMode.custom);
    expect(changed.rounds, emom.rounds);
    expect(changed.roundRestSeconds, emom.roundRestSeconds);
    final tabata = timerModeCandidate(source, WorkoutTimerMode.tabata);
    expect(workoutModuleDuration(tabata), 240);
    final interval = editTimerBlocks(tabata, [
      tabata.intervalBlocks.single.copyWith(workSeconds: 21),
    ]);
    expect(interval.timerMode, WorkoutTimerMode.interval);
    expect(interval.includeFinalRest, isTrue);
  });

  test('invalid input cannot apply or replace valid draft values, and can be corrected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = timerEditorControllerProvider(source);
    container.listen(provider, (_, _) {});
    final actions = container.read(provider.notifier);
    actions.setInput('work', '13:99');
    expect(container.read(provider).valid, isFalse);
    expect(container.read(provider).module, source);
    expect(actions.dirty, isTrue);
    actions.showDetails(true);
    expect(container.read(provider).detailed, isFalse);
    actions.setInput('work', '13:20');
    expect(container.read(provider).valid, isTrue);
    expect(actions.dirty, isFalse);
    actions.setInput('repeats', '1000');
    expect(container.read(provider).valid, isFalse);
    actions.setInput('repeats', '999');
    expect(container.read(provider).valid, isTrue);
  });

  test('rest-only conversion, deletion and order preserve complete custom structure', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = timerEditorControllerProvider(custom);
    container.listen(provider, (_, _) {});
    final actions = container.read(provider.notifier);
    actions.setInput('rest', '', blockId: 'b');
    expect(container.read(provider).valid, isFalse);
    actions.blockAction('b', 'delete');
    expect(container.read(provider).valid, isTrue);
    actions.blockAction('c', 'type');
    actions.blockAction('c', 'up');
    final result = container.read(provider).module;
    expect(result.intervalBlocks.map((b) => b.id), ['c', 'a']);
    expect(result.intervalBlocks.first.workSeconds, 0);
    expect(result.intervalBlocks.first.restSeconds, 30);
    expect(result.intervalBlocks.first.sets, 3);
    expect(result.rounds, 3);
    expect(result.roundRestSeconds, 40);
    expect(result.name, source.name);
    actions.blockAction('c', 'type');
    expect(
      container.read(provider).module.intervalBlocks.first.workSeconds,
      60,
    );
  });

  test('EMOM and Tabata final rest totals match shared playback timeline', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = timerEditorControllerProvider(emom);
    container.listen(provider, (_, _) {});
    final actions = container.read(provider.notifier);
    expect(workoutModuleDuration(emom), 2340);
    actions.setFinalRest(false, round: true);
    expect(workoutModuleDuration(container.read(provider).module), 2310);
    expect(container.read(provider).module.timerMode, WorkoutTimerMode.emom);
    actions.replace(timerModeCandidate(source, WorkoutTimerMode.tabata));
    actions.setFinalRest(false);
    final result = container.read(provider).module;
    expect(result.timerMode, WorkoutTimerMode.interval);
    expect(workoutModuleDuration(result), 230);
    expect(workoutModuleTimeline(result).last.isRest, isFalse);
    expect(workoutModuleDuration(source), 860);
  });

  test(
    'For Time cap survives toggling, with unlimited elapsed-time semantics',
    () {
      final initial = createContinuousTimer(
        source,
        mode: WorkoutTimerMode.forTime,
        seconds: 725,
        direction: TimerDirection.down,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = timerEditorControllerProvider(initial);
      container.listen(provider, (_, _) {});
      final actions = container.read(provider.notifier);
      actions.setCapped(false);
      expect(moduleDurationText(container.read(provider).module), '제한시간 없음');
      expect(container.read(provider).module.timerDirection, TimerDirection.up);
      actions.setCapped(true);
      expect(moduleDurationText(container.read(provider).module), '최대 12:05');
      expect(container.read(provider).valid, isTrue);
    },
  );
  test('step limit validation preserves EMOM editing mode until corrected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = timerEditorControllerProvider(emom);
    container.listen(provider, (_, _) {});
    final actions = container.read(provider.notifier);
    actions.setInput('intervals', '100');
    actions.setInput('rounds', '999');
    actions.setFinalRest(false, round: true);
    expect(container.read(provider).valid, isFalse);
    expect(
      timerInputMode(container.read(provider).module),
      WorkoutTimerMode.emom,
    );
    actions.setInput('rounds', '6');
    expect(container.read(provider).valid, isTrue);
    expect(container.read(provider).module.timerMode, WorkoutTimerMode.emom);
  });

  test(
    'detailed custom edits retain compatible timing version and direction',
    () {
      final initial = custom.copyWith(
        timingVersion: 3,
        timerDirection: TimerDirection.up,
      );
      final next = editTimerBlocks(initial, [
        initial.intervalBlocks.first.copyWith(workSeconds: 80),
        ...initial.intervalBlocks.skip(1),
      ]);
      expect(next.timingVersion, 3);
      expect(next.timerDirection, TimerDirection.up);
      expect(next.intervalBlocks.skip(1), initial.intervalBlocks.skip(1));
    },
  );
}
