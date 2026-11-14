// Optional local widget screenshots. No Firebase or media connections.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';

import 'support/main_navigation_fixture.dart';
import 'support/preparation_fixture.dart';

void main() {
  final output = Platform.environment['PREPARATION_SCREENSHOTS'];
  setUpAll(() async {
    final font = FontLoader('Pretendard')
      ..addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
      );
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  for (final spec in [
    ('ready', const Size(390, 844), 1.0),
    ('waiting', const Size(390, 844), 1.0),
    ('empty', const Size(390, 844), 1.0),
    ('ready', const Size(320, 568), 2.0),
  ]) {
    testWidgets('preparation local screenshot $spec', (tester) async {
      tester.view.physicalSize = spec.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = PreparationFixture(
        scene: spec.$1,
        count: spec.$1 == 'empty' ? 0 : 3,
      );
      final source = navigationWorkouts().first;
      final module = WorkoutModule.empty('warmup')
          .copyWith(name: '전신 워밍업', workSeconds: 40, restSeconds: 20, sets: 3);
      final workout = source.copyWith(
        name: '토요일 팀 워크아웃',
        modules: [
          module,
          createIntervalTimer(
            module.copyWith(id: 'main', name: '스쿼트 · 런지 · 버피'),
            workSeconds: 45,
            restSeconds: 15,
            repeats: 6,
            includeFinalRest: false,
          ),
          createContinuousTimer(
            module.copyWith(id: 'finish', name: '팀 피니셔'),
            mode: WorkoutTimerMode.forTime,
            seconds: 0,
            direction: TimerDirection.up,
          ),
        ],
      );
      const captureKey = ValueKey('capture');
      await tester.pumpWidget(
        ProviderScope(
          overrides: fixture.overrides,
          child: MaterialApp(
            theme: XonTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(spec.$3),
                disableAnimations: true,
              ),
              child: RepaintBoundary(key: captureKey, child: child!),
            ),
            home: WorkoutPreparationPage(workout: workout),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String suffix) async {
        expect(tester.takeException(), isNull);
        if (output == null) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/${spec.$1}-${spec.$2.width.toInt()}-scale${spec.$3}-$suffix.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('top');
      await tester.drag(
        find.byKey(const ValueKey('preparation-page-scroll')),
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      await capture('composition');
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
  }
}
