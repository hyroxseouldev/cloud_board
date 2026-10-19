import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/center_slide_template_repository.dart';

class CenterSlideTemplateActions {
  const CenterSlideTemplateActions({
    required this.repository,
    required this.scope,
    required this.isCurrent,
  });
  final CenterSlideTemplateRepository? repository;
  final CenterSlideCatalogScope? scope;
  final bool Function() isCurrent;

  void _guard([CenterSlideRecipe? recipe]) {
    if (repository == null ||
        scope == null ||
        !isCurrent() ||
        (recipe != null && recipe.centerId != scope!.centerId)) {
      throw const AiSlidesFailure(
        '센터 연결을 다시 확인해 주세요.',
        code: 'center_scope_changed',
      );
    }
  }

  Stream<CenterSlideCatalog> watchCatalog() {
    if (scope == null || repository == null || !isCurrent()) {
      return Stream.value(emptyCenterSlideCatalog());
    }
    return repository!.watchCatalog(scope!.ownerId, scope!.centerId).map((
      catalog,
    ) {
      _guard();
      return catalog.centerId == scope!.centerId
          ? catalog
          : emptyCenterSlideCatalog(scope!.centerId);
    });
  }

  Future<Uint8List?> loadBackground(CenterSlideRecipe recipe) async {
    _guard(recipe);
    final result = await repository!.loadBackground(scope!.ownerId, recipe);
    _guard(recipe);
    return result;
  }

  Future<Uint8List> renderDraft(AiSlideDraft draft) async {
    final recipe = draft.centerRecipe;
    if (recipe == null) {
      throw const AiSlidesFailure(
        '센터 템플릿을 확인해 주세요.',
        code: 'center_recipe_missing',
      );
    }
    _guard(recipe);
    final result = await repository!.renderDraft(scope!.ownerId, draft);
    _guard(recipe);
    return result;
  }
}
