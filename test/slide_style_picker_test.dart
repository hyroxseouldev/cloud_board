import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_style_picker.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'slide_editor_features_test.dart' show scrollSettingsTo;

final style = WorkoutModule.empty('saved-style')
    .copyWith(name: 'MAX', workGaugeColor: '#34C759');

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'cancel keeps a style; confirmed deletion refreshes the open sheet',
    (tester) async {
      final repository = LocalSlideEditorRepository(
        SlideEditorLocalDataSource(),
      );
      await repository.saveStyles('local', [style]);
      final original = WorkoutModule.empty('edited').copyWith(name: '슬라이드');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: SlideEditorScreen(
              workoutId: 'style-deletion',
              moduleId: original.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: original,
                onSave: (_) async => false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester
          .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
          .module;
      final open = find.byKey(const ValueKey('slide-load-style'));
      await scrollSettingsTo(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('MAX 스타일 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('스타일을 삭제할까요?'), findsOneWidget);
      expect(await repository.loadStyles('local'), [style]);
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(find.text('MAX'), findsOneWidget);
      expect(await repository.loadStyles('local'), [style]);
      await tester.tap(find.byTooltip('MAX 스타일 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(await repository.loadStyles('local'), isEmpty);
      expect(find.byType(SlideStylePicker), findsOneWidget);
      expect(find.text('MAX'), findsNothing);
      expect(find.textContaining('저장한 스타일이 없습니다.'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
            .module,
        before,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed deletion keeps the style, blocks repeat actions and can retry',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          home: Scaffold(
            body: SlideStylePicker(
              styles: [style],
              slides: const [],
              onDelete: (_) {
                calls++;
                return calls == 1 ? pending.future : Future.value();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('MAX 스타일 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.hourglass_top_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('style-saved-saved-style')),
            )
            .onTap,
        isNull,
      );
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('스타일을 삭제하지 못했습니다.'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      await tester.tap(find.byTooltip('MAX 스타일 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('스타일을 삭제하지 못했습니다.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text keeps color labels whole and style actions reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = LocalSlideEditorRepository(
        SlideEditorLocalDataSource(),
      );
      await repository.saveStyles('local', [
        style.copyWith(name: '아주 긴 이름으로 저장한 수업용 스타일'),
      ]);
      final original = WorkoutModule.empty('large-text').copyWith(name: '슬라이드');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: SlideEditorScreen(
              workoutId: 'large-text',
              moduleId: original.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: original,
                onSave: (_) async => false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollSettingsTo(
        tester,
        find.byKey(const ValueKey('timer-color-scroll')),
      );
      for (final label in ['운동 시간 텍스트', '휴식 시간 텍스트']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length),
        );
        expect(
          boxes.map((box) => box.top).toSet(),
          hasLength(1),
          reason: label,
        );
      }
      final open = find.byKey(const ValueKey('slide-load-style'));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      final delete = find.byTooltip('아주 긴 이름으로 저장한 수업용 스타일 스타일 삭제');
      await tester.scrollUntilVisible(
        delete,
        120,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('slide-style-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, '취소').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
