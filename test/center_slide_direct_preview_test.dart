import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart'
    hide CenterSlideThumbnail;
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/center_slide_template_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_template_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/center_slide_preview.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/center_slide_thumbnail.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_content_editor.dart';

const recipe = CenterSlideRecipe(
  schemaVersion: 2,
  templateId: 'preview',
  revision: 1,
  centerId: 'center',
  width: 1920,
  height: 1080,
  backgroundColor: 0xfff5f0e5,
  fields: [],
  body: CenterSlideBody(
    x: .05,
    y: .2,
    width: .8,
    height: .7,
    fontSize: 48,
    color: 0xff222222,
    headingColor: 0xffdd5500,
    fontFamily: 'Pretendard',
  ),
);
const initial = AiSlideDraft(
  title: '오늘 수업',
  layout: 'list',
  lines: ['스쿼트 10회'],
  centerRecipe: recipe,
  centerColumns: 1,
);

class Repository implements CenterSlideTemplateRepository {
  int renders = 0, backgrounds = 0, thumbnails = 0;
  Completer<Uint8List?>? gate;
  @override
  Future<Uint8List?> loadBackground(
    String owner,
    CenterSlideRecipe recipe,
  ) async {
    backgrounds++;
    return gate == null ? null : await gate!.future;
  }

  @override
  Future<Uint8List?> loadThumbnail(
    String owner,
    CenterSlideRecipe recipe,
  ) async {
    thumbnails++;
    return null;
  }

  @override
  Future<Uint8List> renderDraft(String owner, AiSlideDraft draft) async {
    renders++;
    return Uint8List(8);
  }

  @override
  Stream<CenterSlideCatalog> watchCatalog(String owner, String center) =>
      Stream.value(
        const CenterSlideCatalog(
          revision: 1,
          centerId: 'center',
          centerName: '',
          templates: [
            AiSlideDesign(
              id: 'preview',
              name: 'Preview',
              theme: AiSlideTheme(centerRecipe: recipe, centerColumns: 1),
              sample: initial,
            ),
          ],
        ),
      );
  @override
  void clear() {}
}

void main() {
  testWidgets('explicit auto fit preserves text/columns and can be undone', (
    tester,
  ) async {
    final selected = initial.copyWith(lines: List.filled(12, 'Squat 10'));
    var draft = selected;
    final history = <AiSlideDraft>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => draft = history.removeLast()),
                    child: const Text('Undo fit'),
                  ),
                  AiSlidesContentEditor(
                    draft: draft,
                    warnings: const [],
                    onChanged: (next) => setState(() {
                      history.add(draft);
                      draft = next;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('ai-center-auto-fit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(draft.centerFontSize, isNotNull);
    expect(draft.centerFontSize, lessThanOrEqualTo(recipe.body!.fontSize));
    expect(draft.centerColumns, selected.centerColumns);
    expect(draft.lines, selected.lines);
    await tester.ensureVisible(find.text('Undo fit'));
    await tester.tap(find.text('Undo fit'));
    await tester.pump();
    expect(draft, selected);
  });

  testWidgets(
    'list and IME text edits never call PNG export, background loads once',
    (tester) async {
      final repository = Repository();
      var draft = initial;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            centerSlideTemplateActionsProvider.overrideWithValue(
              CenterSlideTemplateActions(
                repository: repository,
                scope: const CenterSlideCatalogScope(
                  ownerId: 'owner',
                  centerId: 'center',
                ),
                isCurrent: () => true,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      CenterSlideThumbnail(draft: draft),
                      CenterSlidePreview(draft: draft),
                      AiSlidesContentEditor(
                        draft: draft,
                        warnings: const [],
                        onChanged: (next) => setState(() => draft = next),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('ai-center-wod'));
      await tester.ensureVisible(input);
      await tester.tap(input);
      await tester.showKeyboard(input);
      const composing = TextEditingValue(
        text: '스쿼트 10회\n한',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 8, end: 9),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pump();
      expect(
        tester.widget<TextField>(input).controller!.value.composing,
        composing.composing,
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '스쿼트 10회\n한국어 5회',
          selection: TextSelection.collapsed(offset: 14),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(input).controller!;
      expect(controller.text, draft.lines.join('\n'));
      expect(controller.selection, const TextSelection.collapsed(offset: 14));
      expect(
        find.byKey(const ValueKey('center-slide-direct-canvas')),
        findsOneWidget,
      );
      expect(repository.renders, 0);
      expect(repository.backgrounds, 1);
      expect(
        repository.thumbnails,
        0,
      ); // Old catalog placeholder needs no image.
    },
  );

  test('pending background completes using the latest draft only', () async {
    final repository = Repository()..gate = Completer<Uint8List?>();
    final container = ProviderContainer(
      overrides: [
        centerSlideTemplateActionsProvider.overrideWithValue(
          CenterSlideTemplateActions(
            repository: repository,
            scope: const CenterSlideCatalogScope(
              ownerId: 'owner',
              centerId: 'center',
            ),
            isCurrent: () => true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final catalog = container.listen(centerSlideCatalogProvider, (_, _) {});
    await container.read(centerSlideCatalogProvider.future);
    final old = container.listen(
      centerSlidePreviewProvider(initial),
      (_, _) {},
    );
    final newer = initial.copyWith(lines: ['최신 25회']);
    final latest = container.listen(
      centerSlidePreviewProvider(newer),
      (_, _) {},
    );
    old.close();
    repository.gate!.complete(null);
    final layout = await container.read(
      centerSlidePreviewProvider(newer).future,
    );
    expect(layout.flow!.placements.single.text, '최신 25회');
    expect(repository.renders, 0);
    latest.close();
    catalog.close();
    await container.pump();
  });
}
