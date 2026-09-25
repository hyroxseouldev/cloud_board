import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final original = WorkoutModule.empty('timer-test').copyWith(
  name: '수업',
  workSeconds: 90,
  restSeconds: 45,
  sets: 5,
  showTimer: false,
);
final provider = slideEditorControllerProvider(
  'timer-workout',
  original,
  'local',
);

Future<ProviderContainer> openEditor(
  WidgetTester tester,
  Future<bool> Function(WorkoutModule) save,
) async {
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
          guard: ExitGuard(),
          workoutId: 'timer-workout',
          moduleId: original.id,
          request: SlideEditRequest(module: original, onSave: save),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SlideEditorScreen)),
  );
}

Future<void> select(WidgetTester tester, String key, int index) async {
  tester
      .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
      .onSelectedItemChanged!(index);
  await tester.pump();
}

void main() {
  for (final size in [
    const Size(834, 1194),
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets(
      'apply changes draft only; slide save persists all changes at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final saved = <WorkoutModule>[];
        final container = await openEditor(tester, (module) async {
          saved.add(module);
          return true;
        });
        container
            .read(provider.notifier)
            .update(original.copyWith(name: '수정 이름', text: '본문 초안'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        final sheet = tester.getRect(
          find.byKey(const ValueKey('timer-editor-sheet')),
        );
        expect(sheet.top, greaterThan(0));
        expect(sheet.width, lessThanOrEqualTo(720));
        expect(find.text('운동 07:30'), findsOneWidget);
        await select(tester, 'combined-minutes-picker', 2);
        await select(tester, 'combined-seconds-picker', 10);
        await select(tester, 'combined-set-count-picker', 2);
        // Editing the sheet must not leak into the parent draft or storage.
        expect(container.read(provider).module.workSeconds, 90);
        expect(container.read(provider).module.sets, 5);
        expect(find.text('운동 06:30'), findsOneWidget);
        expect(saved, isEmpty);
        await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
        await tester.pumpAndSettle();
        expect(find.text('타이머 편집'), findsNothing);
        expect(saved, isEmpty);
        expect(container.read(provider).saved.workSeconds, 90);
        expect(container.read(provider).module.workSeconds, 130);
        expect(container.read(provider).module.sets, 3);
        expect(container.read(provider).module.text, '본문 초안');
        expect(container.read(provider).dirty, isTrue);
        // Reopening sees the applied draft; closing an untouched sheet is clean.
        await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
        await tester.pumpAndSettle();
        expect(find.text('운동 06:30'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
        await tester.pumpAndSettle();
        expect(find.text('적용하지 않고 닫을까요?'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('slide-save-button')));
        await tester.pumpAndSettle();
        expect(saved, hasLength(1));
        expect(saved.single.workSeconds, 130);
        expect(saved.single.name, '수정 이름');
        expect(saved.single.text, '본문 초안');
        expect(container.read(provider).dirty, isFalse);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('slide-save-button')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'discard returns to sheet entry timing, preserving applied draft',
    (tester) async {
      final saved = <WorkoutModule>[];
      final container = await openEditor(tester, (module) async {
        saved.add(module);
        return true;
      });
      await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
      await tester.pumpAndSettle();
      await select(tester, 'combined-minutes-picker', 2);
      await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
      await tester.pumpAndSettle();
      final applied = container.read(provider).module;
      expect(applied.workSeconds, 150);
      await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
      await tester.pumpAndSettle();
      await select(tester, 'combined-minutes-picker', 4);
      await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
      await tester.pumpAndSettle();
      expect(find.text('적용하지 않고 닫을까요?'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module, applied);
      await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용 안 하고 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('타이머 편집'), findsNothing);
      expect(container.read(provider).module, applied);
      expect(container.read(provider).saved, original);
      expect(saved, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed slide save preserves applied timing and supports retry', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var calls = 0;
    final container = await openEditor(tester, (_) {
      calls++;
      return calls == 1 ? pending.future : Future.value(true);
    });
    await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
    await tester.pumpAndSettle();
    await select(tester, 'combined-minutes-picker', 2);
    await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    final save = find.byKey(const ValueKey('slide-save-button'));
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(container.read(provider).module.workSeconds, 150);
    expect(container.read(provider).saved.workSeconds, 90);
    expect(container.read(provider).dirty, isTrue);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(container.read(provider).saved.workSeconds, 150);
    expect(container.read(provider).dirty, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
