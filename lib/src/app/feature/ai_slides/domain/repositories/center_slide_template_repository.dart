import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

abstract interface class CenterSlideTemplateRepository {
  Stream<CenterSlideCatalog> watchCatalog(String ownerId, String centerId);
  Future<Uint8List?> loadBackground(String ownerId, CenterSlideRecipe recipe);
  Future<Uint8List> renderDraft(String ownerId, AiSlideDraft draft);

  /// Permanently invalidate this scope and discard its private memory caches.
  void clear();
}
