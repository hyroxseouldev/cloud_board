// Actual production TimerEditorScreen and repository fixture; no TV/network.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/timer_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('capture real timer wheels with Pretendard', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
      (
        name: 'phone-custom',
        size: const Size(390, 844),
        scale: 1.0,
        mode: WorkoutTimerMode.custom,
      ),
      (
        name: 'small-custom',
        size: const Size(320, 568),
        scale: 1.0,
        mode: WorkoutTimerMode.custom,
      ),
      (
        name: 'large-text-custom',
        size: const Size(320, 844),
        scale: 2.0,
        mode: WorkoutTimerMode.custom,
      ),
      (
        name: 'landscape-custom',
        size: const Size(844, 390),
        scale: 1.0,
        mode: WorkoutTimerMode.custom,
      ),
      (
        name: 'tablet-custom',
        size: const Size(834, 1194),
        scale: 1.0,
        mode: WorkoutTimerMode.custom,
      ),
      (
        name: 'desktop-custom',
        size: const Size(1440, 900),
        scale: 1.0,
        mode: WorkoutTimerMode.custom,
      ),
      (
        name: 'phone-amrap',
        size: const Size(390, 844),
        scale: 1.0,
        mode: WorkoutTimerMode.amrap,
      ),
      (
        name: 'phone-emom',
        size: const Size(390, 844),
        scale: 1.0,
        mode: WorkoutTimerMode.emom,
      ),
    ]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = scene.size * 2;
      final custom = WorkoutModule.empty(scene.name).copyWith(
        name: 'SINGLE : AMRAP',
        workSeconds: 150,
        restSeconds: 30,
        sets: 1,
        timerMode: WorkoutTimerMode.custom,
        intervalBlocks: const [
          WorkoutIntervalBlock(
            id: 'one',
            workSeconds: 150,
            restSeconds: 30,
            sets: 1,
          ),
          WorkoutIntervalBlock(
            id: 'two',
            workSeconds: 120,
            restSeconds: 0,
            sets: 1,
          ),
        ],
      );
      final module = scene.mode == WorkoutTimerMode.custom
          ? custom
          : timerModeCandidate(custom, scene.mode);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(scene.name),
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(
              LocalSlideEditorRepository(SlideEditorLocalDataSource()),
            ),
          ],
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scene.scale),
                  padding: const EdgeInsets.only(top: 20, bottom: 24),
                  viewPadding: const EdgeInsets.only(top: 20, bottom: 24),
                ),
                child: child!,
              ),
              home: TimerEditorScreen(
                workoutId: 'capture',
                original: module,
                scope: 'local',
                onSelectBlock: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scene.scale > 1 || scene.size.height < 600) {
        final wheel = find.byKey(
          ValueKey(
            '${scene.mode == WorkoutTimerMode.custom ? 'one-work' : 'timer-work'}-minutes-wheel',
          ),
        );
        await tester.ensureVisible(wheel);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: scene.name);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        find.byKey(const ValueKey('apply-timer-editor')).hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design/sta179/implemented/${scene.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
