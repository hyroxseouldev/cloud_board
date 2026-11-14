import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/main_navigation_fixture.dart';
import 'support/ui_layout_evidence.dart';

void main() {
  testWidgets('current library card reference for home design choice', (
    tester,
  ) async {
    await loadLayoutFonts(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = await tester.runAsync(navigationPreviewImage);
    final data = NavigationPreviewData(active: false, imageSource: source!);
    addTearDown(data.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: data.container,
        child: const RepaintBoundary(
          key: ValueKey('library-reference'),
          child: MainNavigationPreview(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    data.container.read(appRouterProvider).go('/slides');
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        workoutImageProvider(source, (width: 128, height: 128)),
        tester.element(find.byKey(const ValueKey('library-reference'))),
      ),
    );
    await captureLayout(
      tester,
      find.byKey(const ValueKey('library-reference')),
      'library-current-390',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: layoutEvidenceDirectory.isEmpty);
}
