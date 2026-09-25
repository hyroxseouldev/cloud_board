import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(834, 1194),
  ]) {
    testWidgets('four tabs preserve draft and color validation at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = WorkoutModule.empty('tab-slide').copyWith(
        name: '슬라이드',
        workSeconds: 90,
        restSeconds: 30,
        sets: 3,
        text: '기존 본문',
      );
      final saved = <WorkoutModule>[];
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
              workoutId: 'tabs',
              moduleId: original.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: original,
                onSave: (value) async {
                  saved.add(value);
                  return false;
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
      final provider = slideEditorControllerProvider('tabs', original, 'local');
      final titleButton = find.byKey(const ValueKey('slide-title-button'));
      expect(find.widgetWithText(TextFormField, '슬라이드 제목'), findsNothing);
      await tester.tap(titleButton);
      await tester.pumpAndSettle();
      final titleInput = find.widgetWithText(TextFormField, '슬라이드 제목');
      await tester.enterText(titleInput, '취소할 제목');
      expect(container.read(provider).module.name, original.name);
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(container.read(provider).dirty, isFalse);
      await tester.tap(titleButton);
      await tester.pumpAndSettle();
      await tester.enterText(titleInput, '   ');
      await tester.tap(find.widgetWithText(FilledButton, '변경'));
      await tester.pumpAndSettle();
      expect(find.text('슬라이드 제목을 입력해 주세요.'), findsOneWidget);
      expect(container.read(provider).module.name, original.name);
      await tester.enterText(titleInput, '  다이얼로그 제목  ');
      await tester.tap(find.widgetWithText(FilledButton, '변경'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module.name, '다이얼로그 제목');
      expect(find.byTooltip('실행 취소'), findsNothing);
      expect(find.byTooltip('다시 실행'), findsNothing);
      final modeToggle = find.byKey(const ValueKey('timer-display-toggle'));
      for (final label in ['안 보임', '숫자만', '숫자 + 게이지']) {
        await tester.ensureVisible(modeToggle);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: modeToggle, matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        final current = container.read(provider).module;
        expect(current.showTimer, label != '안 보임');
        expect(current.showTimerGauge, label == '숫자 + 게이지');
        expect(current.workSeconds, original.workSeconds);
        expect(current.restSeconds, original.restSeconds);
        expect(current.sets, original.sets);
      }
      final bar = find.byKey(const ValueKey('slide-editor-tabs'));
      expect(find.text('템플릿'), findsNothing);
      final barY = tester.getTopLeft(bar).dy;
      for (final title in ['타이머', '배경', '소리', '라이브러리']) {
        expect(
          find.descendant(of: bar, matching: find.text(title)).hitTestable(),
          findsOneWidget,
        );
      }
      Future<void> tab(String label) async {
        await tester.tap(find.descendant(of: bar, matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(bar).dy, barY);
      }

      Future<void> reveal(Finder target) async {
        final scroll = find
            .descendant(
              of: find.byKey(const ValueKey('slide-editor-settings')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scroll).position;
        position.jumpTo(0);
        await tester.pump();
        for (
          var i = 0;
          i < 100 &&
              target.evaluate().isEmpty &&
              position.pixels < position.maxScrollExtent;
          i++
        ) {
          position.jumpTo(
            (position.pixels + 20).clamp(0, position.maxScrollExtent),
          );
          await tester.pump();
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }

      final indicator = find.byKey(const ValueKey('slide-tab-indicator'));
      final startX = tester.getTopLeft(indicator).dx;
      await tester.tap(find.descendant(of: bar, matching: find.text('배경')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final movingX = tester.getTopLeft(indicator).dx;
      expect(movingX, greaterThan(startX));
      // Retarget before the first animation finishes.
      await tester.tap(find.descendant(of: bar, matching: find.text('소리')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(indicator).dx, greaterThan(movingX));
      await tab('배경');
      final body = find.widgetWithText(TextFormField, '화면 텍스트');
      await reveal(body);
      await tester.enterText(body, '변경 본문');
      await tab('소리');
      await reveal(find.text('소리 종류와 볼륨은 워크아웃 설정을 따릅니다.'));
      expect(find.text('소리 종류와 볼륨은 워크아웃 설정을 따릅니다.'), findsOneWidget);
      await tab('소리');
      final beep = find.widgetWithText(SwitchListTile, '전환음');
      await reveal(beep);
      await tester.tap(beep);
      await tester.pumpAndSettle();
      await tab('배경');
      final titleToggle = find.widgetWithText(SwitchListTile, '화면 제목 표시');
      await reveal(titleToggle);
      await tester.tap(titleToggle);
      await tester.pumpAndSettle();
      expect(container.read(provider).module.appearance.showTitle, isFalse);
      await tab('타이머');
      final color = find.byKey(const ValueKey('color-swatch-운동 게이지'));
      await reveal(color);
      await tester.tap(color);
      await tester.pumpAndSettle();
      final hex = find.byKey(const ValueKey('picker-hex-input'));
      await tester.ensureVisible(hex);
      await tester.enterText(hex, '#invalid');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '선택'))
            .onPressed,
        isNull,
      );
      expect(
        container.read(provider).module.workGaugeColor,
        original.workGaugeColor,
      );
      await tester.enterText(hex, '#112233');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '선택'));
      await tester.pumpAndSettle();
      final colorRow = find.byKey(const ValueKey('timer-color-scroll'));
      final firstColor = find.byKey(const ValueKey('color-swatch-세트 숫자'));
      final lastColor = find.byKey(const ValueKey('color-swatch-휴식 시간 텍스트'));
      expect(
        tester.getTopLeft(firstColor).dy,
        closeTo(tester.getTopLeft(lastColor).dy, 1),
      );
      await tester.drag(colorRow, const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(lastColor);
      await tester.pumpAndSettle();
      expect(lastColor.hitTestable(), findsOneWidget);
      await tab('배경');
      await reveal(body);
      expect(tester.widget<TextFormField>(body).controller!.text, '변경 본문');
      await tester.tap(find.byKey(const ValueKey('slide-save-button')));
      await tester.pumpAndSettle();
      expect(
        saved.single,
        original.copyWith(
          name: '다이얼로그 제목',
          text: '변경 본문',
          beep: !original.beep,
          workGaugeColor: '#112233',
          appearance: original.appearance.copyWith(showTitle: false),
        ),
      );
      expect(container.read(provider).module.text, '변경 본문');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
