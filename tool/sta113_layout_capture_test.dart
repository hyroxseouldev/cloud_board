import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../test/slide_editor_features_test.dart' show scrollSettingsTo;

void main() {
  testWidgets('capture STA-113 production widgets at phone size', (
    tester,
  ) async {
    final oldShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = oldShadows);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    for (final font in [
      ('Pretendard', 'assets/fonts/pretendard/Pretendard-Regular.otf'),
      (
        'RacingSansOne',
        'assets/fonts/racing_sans_one/RacingSansOne-Regular.ttf',
      ),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureKey = GlobalKey();
    final module = WorkoutModule.empty('warmup').copyWith(
      name: 'WARM UP',
      workSeconds: 180,
      designTemplate: 'stationd-v2-numbered',
      designAccentColor: 0xFF54B2EC,
      designBackgroundColor: 0xFFFFFFFF,
      designTextColor: 0xFF000000,
      workGaugeColor: '#00B5EB',
      restGaugeColor: '#999999',
      workTextColor: '#000000',
      restTextColor: '#000000',
      appearance: const SlideAppearance(setsColor: 0xFF000000),
      text:
          'Cat & Cow\nBird Dog +\nA-Skip\nKnee Rotation\nStar Jump\nQuick Feet',
    );
    final workout =
        Workout.empty(
          'demo',
          const WorkoutAuthor(id: 'demo', displayName: 'Demo', photoUrl: null),
        ).copyWith(
          brandL: 'CloudBoard',
          brandR: 'SWEAT',
          modules: [
            module,
            module.copyWith(id: 'explain', name: '설명'),
            module.copyWith(
              id: 'main',
              name: '메인 운동',
              workGaugeColor: '#EF4444',
            ),
          ],
        );
    final repository = LocalSlideEditorRepository(SlideEditorLocalDataSource());
    await repository.saveStyles('demo', [
      module.copyWith(id: 'max', name: 'MAX', workGaugeColor: '#34C759'),
      module.copyWith(id: 'hyrox', name: 'HYROX', workGaugeColor: '#EF4444'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          slideEditorRepositoryProvider.overrideWithValue(repository),
          workoutPreviewProvider(workout).overrideWith((ref) async => workout),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 62, bottom: 34)),
              child: XonTheme.responsiveBuilder(context, child),
            ),
            home: SlideEditorScreen(
              workoutId: workout.id,
              moduleId: module.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: module,
                workout: workout,
                onSave: (_) async => false,
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('docs/design/style-layout-2026-10-12')
          ..createSync(recursive: true);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await tester.pumpAndSettle();
    await scrollSettingsTo(
      tester,
      find.byKey(const ValueKey('timer-color-scroll')),
    );
    await capture('timer-settings');
    await tester.ensureVisible(find.byKey(const ValueKey('slide-load-style')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('slide-load-style')));
    await capture('style-picker');
    await tester.tap(find.byTooltip('MAX 스타일 삭제'));
    await capture('delete-confirmation');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDisableShadows = oldShadows;
  });
}
