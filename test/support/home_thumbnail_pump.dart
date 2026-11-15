import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_workout_thumbnail.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Let real image codecs complete before settling the animated placeholder.
/// Fake-clock pumpAndSettle alone cannot make a native decode finish.
Future<void> pumpHomeThumbnails(WidgetTester tester) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final images = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byType(HomeWorkoutThumbnail),
            matching: find.byType(Image),
          ),
        )
        .toList();
    for (final image in images) {
      await tester.runAsync(
        () => precacheImage(
          image.image,
          tester.element(find.byType(HomeWorkoutThumbnail).first),
          // The production errorBuilder is asserted by the failure tests.
          onError: (_, _) {},
        ),
      );
    }
    await tester.pump();
    if (find.byType(WorkoutImageSkeleton).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame) {
      break;
    }
  }
  expect(
    find.byType(WorkoutImageSkeleton),
    findsNothing,
    reason: 'Completed fixture requests must leave the loading state',
  );
  await tester.pumpAndSettle();
}
