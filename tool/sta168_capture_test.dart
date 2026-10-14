// Production control widgets, local fixture only. No account, TV or network calls.
// flutter test --no-pub tool/sta168_capture_test.dart
// For baseline evidence run the same file at 38a2f60 with STA168_PHASE=before.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _phase = String.fromEnvironment('STA168_PHASE', defaultValue: 'after');

void main() {
  testWidgets('capture elapsed/remaining production controls', (tester) async {
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
        name: 'phone-zero',
        size: const Size(390, 844),
        scale: 1.0,
        elapsed: 0,
        intervals: false,
        enabled: true,
      ),
      (
        name: 'phone-11s',
        size: const Size(390, 844),
        scale: 1.0,
        elapsed: 11000,
        intervals: false,
        enabled: true,
      ),
      (
        name: 'phone-half',
        size: const Size(390, 844),
        scale: 1.0,
        elapsed: 90000,
        intervals: false,
        enabled: true,
      ),
      (
        name: 'phone-complete',
        size: const Size(390, 844),
        scale: 1.0,
        elapsed: 180000,
        intervals: false,
        enabled: true,
      ),
      (
        name: 'phone-intervals',
        size: const Size(390, 844),
        scale: 1.0,
        elapsed: 75000,
        intervals: true,
        enabled: true,
      ),
      (
        name: 'phone-disabled',
        size: const Size(390, 844),
        scale: 1.0,
        elapsed: 11000,
        intervals: false,
        enabled: false,
      ),
      (
        name: 'small-text2x',
        size: const Size(320, 844),
        scale: 2.0,
        elapsed: 11000,
        intervals: false,
        enabled: true,
      ),
      (
        name: 'tablet',
        size: const Size(834, 1194),
        scale: 1.0,
        elapsed: 11000,
        intervals: false,
        enabled: true,
      ),
      (
        name: 'desktop',
        size: const Size(1440, 900),
        scale: 1.0,
        elapsed: 11000,
        intervals: false,
        enabled: true,
      ),
    ]) {
      tester.view.physicalSize = scene.size * 2;
      tester.view.devicePixelRatio = 2;
      final module = WorkoutModule.empty('warmup').copyWith(
        name: scene.intervals ? '인터벌' : '웜업',
        beep: false,
        workSeconds: scene.intervals ? 60 : 180,
        restSeconds: scene.intervals ? 30 : 0,
        sets: scene.intervals ? 2 : 1,
      );
      final frame = rehearsalFrame(module, scene.elapsed);
      final key = GlobalKey();
      Widget timeline(WorkoutTimelineSection section) => WorkoutControlTimeline(
        section: section,
        durations: const [180],
        modules: [module],
        currentModule: 0,
        elapsedMs: scene.elapsed,
        onSeek: scene.enabled ? (_, _) async {} : null,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scene.scale)),
              child: child!,
            ),
            home: WorkoutControlPanel(
              title: '기초 체력 수업',
              moduleCount: 1,
              currentModule: 0,
              paused: true,
              busy: false,
              onPrevious: () {},
              onToggle: () {},
              onNext: () {},
              onExit: () {},
              onMinimize: () {},
              onSelectModule: (_) async {},
              previewBuilder: (_, _) => LayoutBuilder(
                builder: (_, constraints) => WorkoutSlideCanvas(
                  module: module,
                  isRest: frame.isRest,
                  secondsLeft: frame.secondsLeft,
                  remainingMs: frame.remainingMs,
                  durationMs: frame.durationMs,
                  set: frame.set,
                  totalSets: frame.totalSets,
                  isPaused: true,
                  brandL: 'CloudBoard',
                  brandR: '',
                  scale: constraints.maxWidth / 1280,
                ),
              ),
              progress: timeline(WorkoutTimelineSection.progress),
              timeline: timeline(WorkoutTimelineSection.detail),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scene.scale > 1) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('slide-detail-timeline')),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: scene.name);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design/sta168/$_phase/${scene.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
