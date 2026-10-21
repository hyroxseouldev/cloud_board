import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_raster_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/slide_studio_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/slide_studio_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/ai_raster_fakes.dart';
import 'support/main_navigation_fixture.dart';
import 'support/slide_studio_fakes.dart';

// Exercise the shipped ShellRoute + StatefulShellRoute + editor hierarchy,
// rather than a standalone GoRoute that cannot reproduce shared navigator reuse.
void main() {
  for (final width in [390.0, 1024.0]) {
    testWidgets(
      'production router library round trip preserves studio at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (_) async => null,
        );
        final data = NavigationPreviewData(active: false);
        final repository = FakeStudioRepository();
        final container = ProviderContainer(
          parent: data.container,
          overrides: [
            aiSlidesOwnerIdProvider.overrideWithValue(previewUser.id),
            aiSlideDesignOwnerIdProvider.overrideWithValue(null),
            aiSlideDesignStoreIdProvider.overrideWithValue(null),
            centerSlideCatalogScopeProvider.overrideWithValue(null),
            centerSlideCatalogProvider.overrideWith(
              (_) => Stream.value(emptyCenterSlideCatalog()),
            ),
            slideStudioActionsProvider.overrideWithValue(
              SlideStudioActions(repository),
            ),
            aiRasterActionsProvider.overrideWithValue(
              AiRasterActions(FakeRasterRepository()),
            ),
            slideEditorActionsProvider.overrideWithValue(
              SlideEditorActions(
                LocalSlideEditorRepository(_MemoryEditorSource()),
              ),
            ),
            slideEditorControllerProvider.overrideWith2(
              (_) => SlideEditorController(),
            ),
            slideTemplatesControllerProvider.overrideWith2(
              (_) => _SavedStudioSlides(repository),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MainNavigationPreview(),
            ),
          );
          await tester.pumpAndSettle();
          final router = container.read(appRouterProvider);
          router.push<void>('/editor/preview-0');
          await tester.pumpAndSettle();
          router.push<void>('/editor/preview-0/images/create');
          await tester.pumpAndSettle();
          final studioElement = tester.element(find.byType(SlideStudioPage));
          final studioScope = ProviderScope.containerOf(studioElement);
          final controller = studioScope.read(
            slideStudioControllerProvider.notifier,
          );
          const source = 'Run 800m\nSquat 22.5kg × 12';
          controller.edit(
            studioScope
                .read(slideStudioControllerProvider)
                .input
                .copyWith(raw: source),
          );
          await controller.generateTemplate();
          await controller.save();
          // This fixture uses a one-shot library stream; refresh it after the
          // mock acknowledgment as the real repository's watch would update.
          container.invalidate(
            slideTemplatesControllerProvider(previewUser.id),
          );
          await tester.pumpAndSettle();
          final saved = studioScope.read(slideStudioControllerProvider).result!;
          expect(saved.savedModule, isNotNull);
          // Returning must preserve both a saved result and subsequent input.
          controller.edit(saved.input.copyWith(raw: '$source\nRow 500m'));
          await tester.pumpAndSettle();

          for (var visit = 0; visit < 2; visit++) {
            if (width < 560) {
              await tester.tap(find.byTooltip('저장된 이미지'));
            } else {
              await tester.tap(find.text('저장된 이미지'));
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(SlideLibraryScreen), findsOneWidget);
            expect(
              tester
                  .widget<SlideLibraryScreen>(find.byType(SlideLibraryScreen))
                  .asMainTab,
              isFalse,
            );
            expect(
              tester
                  .widget<SlideLibraryScreen>(find.byType(SlideLibraryScreen))
                  .imagesOnly,
              isTrue,
            );
            expect(
              find.byKey(const ValueKey('library-category-tabs')),
              findsNothing,
            );
            expect(find.byKey(const ValueKey('text-only')), findsNothing);
            expect(find.byType(MainNavigationDock), findsNothing);
            expect(find.text('오늘의 수업'), findsWidgets);
            expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
            expect(
              GoRouterState.of(tester.element(find.byType(SlideLibraryScreen)))
                  .uri
                  .path,
              '/editor/preview-0/images/create/library',
            );
            if (visit == 0) {
              await tester.tap(
                find
                    .descendant(
                      of: find.byKey(ValueKey(saved.id)),
                      matching: find.text('오늘의 수업'),
                    )
                    .first,
              );
              await tester.pumpAndSettle();
              expect(find.byType(SavedSlideEditorScreen), findsOneWidget);
              await tester.pageBack();
              await tester.pumpAndSettle();
              expect(find.byType(SlideLibraryScreen), findsOneWidget);
              await tester.pageBack();
            } else {
              await tester.binding.handlePopRoute();
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.element(find.byType(SlideStudioPage)),
              same(studioElement),
            );
            expect(
              studioScope.read(slideStudioControllerProvider.notifier),
              same(controller),
            );
            final restored = studioScope.read(slideStudioControllerProvider);
            expect(restored.result, same(saved));
            expect(restored.input.raw, '$source\nRow 500m');
            expect(restored.dirty, isTrue);
            expect(
              tester
                  .widget<TextField>(find.byKey(const ValueKey('studio-wod')))
                  .controller!
                  .text,
              '$source\nRow 500m',
            );
          }
          expect(repository.generations, 0);
          expect(repository.saves, 1);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          data.dispose();
          await tester.pump();
        }
      },
    );
  }
}

class _SavedStudioSlides extends SlideTemplatesController {
  _SavedStudioSlides(this.repository);
  final FakeStudioRepository repository;
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value([
    for (final module in repository.saved.values)
      module.copyWith(
        imageSource:
            'assets/slide_templates/stationd_unbroken_single_original.png',
      ),
    WorkoutModule.empty('text-only').copyWith(name: '텍스트 전용', favorite: true),
  ]);
}

class _MemoryEditorSource extends SlideEditorLocalDataSource {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String? value) async {}
}
