// Local production-widget captures. No account, TV or network interaction.
// flutter test --no-pub tool/sta177_capture_test.dart --dart-define=STA177_PHASE=before
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _phase = String.fromEnvironment('STA177_PHASE', defaultValue: 'after');

void main() {
  testWidgets('capture production editor responsive layouts', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
      );
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final scene in [
      (name: 'phone', size: const Size(390, 844), scale: 1.0, keyboard: 0.0),
      (name: 'small', size: const Size(320, 568), scale: 1.0, keyboard: 0.0),
      (
        name: 'large-text',
        size: const Size(320, 844),
        scale: 2.0,
        keyboard: 0.0,
      ),
      (
        name: 'landscape',
        size: const Size(844, 390),
        scale: 1.0,
        keyboard: 0.0,
      ),
      (name: 'tablet', size: const Size(834, 1194), scale: 1.0, keyboard: 0.0),
      (name: 'desktop', size: const Size(1440, 900), scale: 1.0, keyboard: 0.0),
      (
        name: 'keyboard',
        size: const Size(390, 844),
        scale: 1.0,
        keyboard: 300.0,
      ),
    ]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = scene.size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.viewInsets = const FakeViewPadding();
      final key = GlobalKey();
      final module = WorkoutModule.empty('capture-${scene.name}').copyWith(
        name: '전신 스트레칭',
        text: '호흡을 고르며 천천히 움직여요',
        workSeconds: 180,
        restSeconds: 30,
        sets: 3,
        beep: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(scene.name),
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(
              LocalSlideEditorRepository(SlideEditorLocalDataSource()),
            ),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scene.scale),
                  padding: EdgeInsets.only(
                    bottom: scene.keyboard == 0 ? 34 : 0,
                  ),
                  viewPadding: const EdgeInsets.only(bottom: 34),
                ),
                child: child!,
              ),
              home: SlideEditorScreen(
                workoutId: 'capture',
                moduleId: module.id,
                guard: ExitGuard(),
                request: SlideEditRequest(
                  module: module,
                  onSave: (_) async => true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scene.keyboard > 0) {
        await tester.tap(find.text('배경'));
        await tester.pumpAndSettle();
        final field = find.widgetWithText(TextFormField, '화면 텍스트');
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        expect(field.hitTestable(), findsOneWidget);
        await tester.tap(field);
        tester.view.viewInsets = FakeViewPadding(bottom: scene.keyboard * 2);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(of: field, matching: find.byType(EditableText)),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        if (_phase == 'after') {
          expect(
            find.byKey(const ValueKey('slide-title-button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('slide-preview-card')),
            findsNothing,
          );
          expect(
            tester
                .getRect(find.byKey(const ValueKey('slide-editor-tabs')))
                .bottom,
            scene.size.height - scene.keyboard,
          );
        }
      }
      expect(tester.takeException(), isNull, reason: scene.name);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design/sta177/$_phase/${scene.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
