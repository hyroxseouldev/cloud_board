import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

// Local production-widget fixtures; no account or purchase writes.
// flutter test --no-pub tool/sta155_156_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_usage.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/plan_usage_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/standby_branding.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/standby_settings_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test/plan_usage_branding_test.dart' show planFixture;
import '../test/support/management_journey_fixture.dart';

void main() {
  testWidgets('STA155 usage and STA156 branding production captures', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
      );
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final original = BrandTemplate.initial().copyWith(
      storeName: '리듬 스튜디오',
      standbyMessage: '오늘도 나의 속도로 시작해요',
      showCloudBoardLogo: false,
    );
    for (final scene in [
      (
        name: 'free-home-6-of-7',
        plan: 'free',
        count: 6,
        width: 390.0,
        height: 844.0,
        scale: 1.0,
        kind: 'home',
      ),
      (
        name: 'free-home-7-of-7-text2x',
        plan: 'free',
        count: 7,
        width: 320.0,
        height: 844.0,
        scale: 2.0,
        kind: 'home',
      ),
      (
        name: 'free-brand-settings',
        plan: 'free',
        count: 7,
        width: 390.0,
        height: 844.0,
        scale: 1.0,
        kind: 'settings',
      ),
      (
        name: 'plus-brand-settings',
        plan: 'plus',
        count: 7,
        width: 390.0,
        height: 844.0,
        scale: 1.0,
        kind: 'settings',
      ),
      (
        name: 'free-tv-1920',
        plan: 'free',
        count: 7,
        width: 1920.0,
        height: 1080.0,
        scale: 1.0,
        kind: 'tv',
      ),
      (
        name: 'plus-tv-1920',
        plan: 'plus',
        count: 7,
        width: 1920.0,
        height: 1080.0,
        scale: 1.0,
        kind: 'tv',
      ),
    ]) {
      final dpr = scene.kind == 'tv' ? 1.0 : 2.0;
      tester.view.physicalSize = Size(scene.width * dpr, scene.height * dpr);
      tester.view.devicePixelRatio = dpr;
      final data = ManagementFixture(
        workouts: [
          for (var i = 0; i < scene.count; i++)
            Workout.empty(
              'class-$i',
              const WorkoutAuthor(
                id: 'coach',
                displayName: '김코치',
                photoUrl: null,
              ),
            ).copyWith(name: '기초 체력 ${i + 1}'),
        ],
      );
      final boundary = GlobalKey();
      final page = switch (scene.kind) {
        'home' => WorkoutListScreen(),
        'settings' => StandbySettingsScreen(guard: ExitGuard()),
        _ => StoreWelcomeBoard(
          brand: brandPreviewForPlan(original, planFixture(scene.plan)),
          now: DateTime(2026, 10, 13, 9, 30),
          nextClass: '10:00 기초 체력',
        ),
      };
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: data.app(
            ProviderScope(
              overrides: [
                planAccessProvider.overrideWith(
                  (_) => Stream.value(planFixture(scene.plan)),
                ),
                planUsageProvider.overrideWith(
                  (_) => Stream.value(
                    PlanUsage(
                      workoutCount: scene.count,
                      savedSlideCount: 3,
                      serverConfirmed: true,
                    ),
                  ),
                ),
                brandTemplateProvider.overrideWith(
                  (_) => Stream.value(original),
                ),
              ],
              child: page,
            ),
            textScale: scene.scale,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final images = tester.elementList(find.byType(Image)).toList();
      await tester.runAsync(
        () => Future.wait(
          images.map(
            (element) =>
                precacheImage((element.widget as Image).image, element),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: scene.name);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: dpr);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design/sta155-156/${scene.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      if (scene.name == 'free-home-7-of-7-text2x') {
        await tester.tap(find.byTooltip('저장 수업 7 / 7 · 사용량 안내'));
        await tester.pumpAndSettle();
        expect(find.text('닫기').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: dpr);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/design/sta155-156/free-home-7-of-7-text2x-usage.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      data.dispose();
    }
  });
}
