import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/center_slide_template_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_template_actions.dart';

const _scope = CenterSlideCatalogScope(
  ownerId: 'owner-a',
  centerId: 'center-a',
);
const _recipe = CenterSlideRecipe(
  templateId: 'recipe',
  revision: 1,
  centerId: 'center-a',
  width: 1600,
  height: 900,
  backgroundColor: 0xff000000,
  fields: [],
);
const _draft = AiSlideDraft(
  title: '수업',
  layout: 'list',
  lines: [],
  centerRecipe: _recipe,
);
Matcher get _changed => isA<AiSlidesFailure>().having(
  (error) => error.code,
  'code',
  'center_scope_changed',
);

void main() {
  test(
    'unresolved identity exposes no private catalog and does not fetch',
    () async {
      final repository = _Repository();
      final actions = CenterSlideTemplateActions(
        repository: repository,
        scope: null,
        isCurrent: () => false,
      );
      expect((await actions.watchCatalog().single).templates, isEmpty);
      await expectLater(actions.loadBackground(_recipe), throwsA(_changed));
      expect(repository.calls, isEmpty);
    },
  );

  test(
    'another center recipe is rejected before any repository call',
    () async {
      final repository = _Repository();
      final actions = CenterSlideTemplateActions(
        repository: repository,
        scope: _scope,
        isCurrent: () => true,
      );
      await expectLater(
        actions.loadBackground(_recipe.copyWith(centerId: 'center-b')),
        throwsA(_changed),
      );
      await expectLater(
        actions.renderDraft(
          _draft.copyWith(centerRecipe: _recipe.copyWith(centerId: 'center-b')),
        ),
        throwsA(_changed),
      );
      expect(repository.calls, isEmpty);
    },
  );

  test(
    'late rendered image cannot survive account or center scope disposal',
    () async {
      final repository = _Repository();
      var current = true;
      final actions = CenterSlideTemplateActions(
        repository: repository,
        scope: _scope,
        isCurrent: () => current,
      );
      final pending = actions.renderDraft(_draft);
      final expectation = expectLater(pending, throwsA(_changed));
      expect(repository.calls, ['render:owner-a:center-a']);
      current = false;
      repository.render.complete(Uint8List.fromList([1, 2, 3]));
      await expectation;
    },
  );

  test('late background bytes cannot survive scope disposal', () async {
    final repository = _Repository();
    var current = true;
    final actions = CenterSlideTemplateActions(
      repository: repository,
      scope: _scope,
      isCurrent: () => current,
    );
    final pending = actions.loadBackground(_recipe);
    final expectation = expectLater(pending, throwsA(_changed));
    current = false;
    repository.background.complete(Uint8List.fromList([1, 2, 3]));
    await expectation;
    expect(repository.calls, ['background:owner-a:center-a']);
  });

  test('mismatched repository catalog cannot reach this center UI', () async {
    final repository = _Repository();
    final actions = CenterSlideTemplateActions(
      repository: repository,
      scope: _scope,
      isCurrent: () => true,
    );
    final result = await actions.watchCatalog().single;
    expect(result.centerId, 'center-a');
    expect(result.templates, isEmpty);
    expect(result.revision, 0);
  });
}

class _Repository implements CenterSlideTemplateRepository {
  final calls = <String>[];
  final background = Completer<Uint8List?>();
  final render = Completer<Uint8List>();
  @override
  Stream<CenterSlideCatalog> watchCatalog(String ownerId, String centerId) {
    calls.add('watch:$ownerId:$centerId');
    return Stream.value(
      const CenterSlideCatalog(
        revision: 7,
        centerId: 'center-b',
        centerName: '다른 센터',
        templates: [],
      ),
    );
  }

  @override
  Future<Uint8List?> loadBackground(String ownerId, CenterSlideRecipe recipe) {
    calls.add('background:$ownerId:${recipe.centerId}');
    return background.future;
  }

  @override
  Future<Uint8List?> loadThumbnail(String ownerId, CenterSlideRecipe recipe) =>
      loadBackground(ownerId, recipe);

  @override
  Future<Uint8List> renderDraft(String ownerId, AiSlideDraft draft) {
    calls.add('render:$ownerId:${draft.centerRecipe!.centerId}');
    return render.future;
  }

  @override
  void clear() {}
}
