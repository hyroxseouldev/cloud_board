import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  for (final size in [const Size(834, 1194), const Size(390, 844)]) {
    testWidgets('timer page shares draft and history at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = WorkoutModule.empty('timer-test')
          .copyWith(name: '수업', workSeconds: 90, restSeconds: 45, sets: 5);
      var saves = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            home: SlideEditorScreen(
              guard: ExitGuard(),
              workoutId: 'timer-workout',
              moduleId: original.id,
              request: SlideEditRequest(
                module: original,
                onSave: (_) async {
                  saves++;
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SlideEditorScreen)),
      );
      final provider = slideEditorControllerProvider(
        'timer-workout',
        original,
        'local',
      );
      await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
      await tester.pumpAndSettle();
      expect(find.text('타이머 편집'), findsOneWidget);
      expect(find.text('운동 07:30'), findsOneWidget);
      expect(find.text('휴식 03:00'), findsOneWidget);
      expect(find.text('운동 01:30 · 휴식 00:45 · 5세트'), findsOneWidget);
      expect(find.byType(CupertinoPicker), findsNWidgets(3));
      Future<void> select(String key, int index) async {
        tester
            .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
            .onSelectedItemChanged!(index);
        await tester.pump();
      }

      await select('combined-minutes-picker', 2);
      await tester.ensureVisible(find.widgetWithText(TextButton, '취소'));
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module.workSeconds, 90);
      await tester.tap(find.byTooltip('시간 블록 펼치기'));
      await tester.pumpAndSettle();
      await select('combined-minutes-picker', 2);
      await select('combined-seconds-picker', 10);
      await select('combined-set-count-picker', 2);
      await tester.ensureVisible(find.widgetWithText(TextButton, '완료'));
      await tester.tap(find.widgetWithText(TextButton, '완료'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module.workSeconds, 130);
      expect(container.read(provider).module.restSeconds, 45);
      expect(container.read(provider).module.sets, 3);
      expect(find.text('운동 06:30'), findsOneWidget);
      expect(find.text('휴식 01:30'), findsOneWidget);
      await tester.tap(find.byTooltip('실행 취소'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module.workSeconds, 90);
      expect(find.text('운동 07:30'), findsOneWidget);
      expect(find.text('휴식 03:00'), findsOneWidget);
      await tester.tap(find.byTooltip('다시 실행'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module.workSeconds, 130);
      final visibility = find.widgetWithText(SwitchListTile, '타이머 표시');
      await tester.ensureVisible(visibility);
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(container.read(provider).module.showTimer, isFalse);
      await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
      await tester.pumpAndSettle();
      expect(find.text('타이머 편집'), findsNothing);
      expect(container.read(provider).module.workSeconds, 130);
      expect(container.read(provider).module.showTimer, isFalse);
      expect(saves, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
