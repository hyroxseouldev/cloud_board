import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/home_thumbnail_loader.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_workout_thumbnail.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'home_thumbnail_test.dart' show tinyImage;
import 'support/ui_layout_evidence.dart';

const baseline = bool.fromEnvironment('HOME_NAV_BASELINE');

void main() {
  testWidgets(
    'thumbnail request, first frame, failure, offstage and cache reuse',
    (tester) async {
      await loadLayoutFonts(tester);
      final pending = Completer<Uint8List?>();
      var calls = 0;
      final cache = HomeThumbnailCache((source, {workoutId, updatedAt}) {
        calls++;
        return source == 'pending' ? pending.future : Future.value(null);
      });
      addTearDown(cache.dispose);
      Future<void> mount(String source, {bool active = true}) =>
          tester.pumpWidget(
            ProviderScope(
              overrides: [
                homeThumbnailCacheProvider('owner').overrideWithValue(cache),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: TickerMode(
                      enabled: active,
                      child: RepaintBoundary(
                        key: const ValueKey('thumbnail-capture'),
                        child: HomeWorkoutThumbnail(
                          ownerId: 'owner',
                          width: 192,
                          workout: WorkoutSummary(
                            id: 'w',
                            name: 'Class',
                            folder: '',
                            imageSource: source,
                            moduleCount: 1,
                            durationSeconds: 30,
                            updatedAt: DateTime(2026),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      Future<void> capture(String name) async {
        if (layoutEvidenceDirectory.isEmpty) return;
        await tester.pump();
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('thumbnail-capture')),
              )
              .toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$layoutEvidenceDirectory/thumbnail-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await mount('pending');
      await tester.pump(const Duration(milliseconds: 200));
      if (!baseline) expect(find.byType(WorkoutImageSkeleton), findsOneWidget);
      await capture('pending');
      if (!baseline)
        expect(tester.binding.transientCallbackCount, greaterThan(0));
      await mount('pending', active: false);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.binding.transientCallbackCount, 0);
      await mount('pending');
      await tester.pump(const Duration(milliseconds: 200));
      if (!baseline) expect(find.byType(WorkoutImageSkeleton), findsOneWidget);
      expect(calls, 1);
      pending.complete(tinyImage());
      await tester.pump();
      await tester.pump();
      final imageWidget = tester.widget<Image>(find.byType(Image));
      // Explicitly exercise the production frame builder before first decode.
      expect(
        imageWidget.frameBuilder!(
          tester.element(find.byType(Image)),
          const SizedBox(),
          null,
          false,
        ),
        baseline ? isA<Center>() : isA<WorkoutImageSkeleton>(),
      );
      await capture('first-frame');
      await tester.runAsync(
        () => precacheImage(
          imageWidget.image,
          tester.element(find.byType(Image)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutImageSkeleton), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(calls, 1);
      await capture('ready');
      await mount('pending');
      await tester.pump();
      expect(tester.widget<Image>(find.byType(Image)).image, imageWidget.image);
      expect(find.byType(WorkoutImageSkeleton), findsNothing);
      expect(calls, 1);
      // A list/grid subtree replacement reuses the same bounded cache future.
      await tester.pumpWidget(const SizedBox.shrink());
      await mount('pending');
      if (!baseline) {
        expect(find.byType(WorkoutImageSkeleton), findsNothing);
        expect(find.byType(Image), findsOneWidget);
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          imageWidget.image,
        );
      }
      expect(calls, 1);
      await mount('pending', active: false);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.binding.transientCallbackCount, 0);
      await mount('pending');
      await tester.pump();
      expect(find.byType(WorkoutImageSkeleton), findsNothing);
      expect(calls, 1);
      await mount('failed');
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutImageSkeleton), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await capture('failure');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
