import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/main_navigation_fixture.dart';

void main() {
  for (final count in [10, 100, 500]) {
    testWidgets(
      'cold editor opens one detail without loading $count catalog rows',
      (tester) async {
        final fixture = NavigationPreviewData(active: false, count: count);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: MaterialApp(
              theme: XonTheme.light,
              home: const WorkoutEditorScreen(workoutId: 'preview-0'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('워크아웃 편집'), findsOneWidget);
        expect(fixture.repository.loads, 0);
        expect(fixture.repository.detailReads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
