import 'dart:ui' as ui;
import 'dart:async';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/private_slide_image_cache.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/center_slide_template_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_template_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

part 'center_slide_catalog_controller.g.dart';

/// An unresolved account/center never borrows AsyncValue's previous data.
@riverpod
CenterSlideCatalogScope? centerSlideCatalogScope(Ref ref) {
  final ownerId = ref.watch(aiSlideDesignOwnerIdProvider);
  if (ownerId == null) return null;
  final user = ref.watch(firebaseAccountUserProvider);
  if (user.isLoading ||
      user.hasError ||
      user.value == null ||
      user.value!.isAnonymous ||
      user.value!.uid != ownerId) {
    return null;
  }
  final onboarding = ref.watch(onboardingControllerProvider);
  if (onboarding.isLoading || onboarding.hasError || !onboarding.hasValue) {
    return null;
  }
  final centerId = onboarding.value!.storeId;
  if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(centerId)) return null;
  return CenterSlideCatalogScope(ownerId: ownerId, centerId: centerId);
}

@riverpod
CenterSlideTemplateActions centerSlideTemplateActions(Ref ref) {
  final scope = ref.watch(centerSlideCatalogScopeProvider);
  // A fresh identity lifetime also handles rapid A -> B -> A transitions before
  // Riverpod releases the old family instance at the end of the frame.
  final lifetime = Object();
  final repository = scope == null
      ? null
      : ref.watch(
          centerSlideTemplateRepositoryProvider(
            scope.ownerId,
            scope.centerId,
            lifetime,
          ),
        );
  var active = true;
  ref.onDispose(() {
    active = false;
    repository?.clear();
  });
  return CenterSlideTemplateActions(
    repository: repository,
    scope: scope,
    isCurrent: () =>
        active &&
        ref.mounted &&
        ref.read(centerSlideCatalogScopeProvider) == scope &&
        scope != null,
  );
}

@riverpod
Stream<CenterSlideCatalog> centerSlideCatalog(Ref ref) =>
    ref.watch(centerSlideTemplateActionsProvider).watchCatalog();

void _requireCatalog(Ref ref) {
  final catalog = ref.watch(centerSlideCatalogProvider);
  if (catalog.isLoading ||
      catalog.hasError ||
      (catalog.value?.revision ?? 0) == 0) {
    throw const AiSlidesFailure(
      '센터 템플릿 권한을 확인하고 있어요.',
      code: 'center_authority_unavailable',
    );
  }
}

/// One decode per recipe/scope, independent of every text edit.
@riverpod
Future<ui.Image?> centerSlideBackground(
  Ref ref,
  CenterSlideRecipe recipe,
) async {
  final actions = ref.watch(centerSlideTemplateActionsProvider);
  _requireCatalog(ref);
  final bytes = await actions.loadBackground(recipe);
  if (bytes == null || !ref.mounted) return null;
  final image = await decodeCenterSlideBackground(
    recipe,
    bytes,
    targetWidth: 1920,
  );
  if (!ref.mounted) {
    image.dispose();
    throw const AiSlidesFailure('센터 연결을 다시 확인해 주세요.');
  }
  ref.onDispose(image.dispose);
  return image;
}

@riverpod
Future<CenterSlideLayout> centerSlidePreview(
  Ref ref,
  AiSlideDraft draft,
) async {
  _requireCatalog(ref);
  final recipe = draft.centerRecipe!;
  await ref.watch(centerSlideBackgroundProvider(recipe).future);
  if (!ref.mounted) throw const AiSlidesFailure('미리보기를 갱신하고 있어요.');
  final layout = prepareCenterSlideLayout(recipe, draft);
  ref.onDispose(layout.dispose);
  return layout;
}

@riverpod
PrivateSlideImageCache centerSlideImageCache(Ref ref) {
  ref.watch(centerSlideTemplateActionsProvider);
  final cache = PrivateSlideImageCache();
  ref.listen(centerSlideCatalogProvider, (_, catalog) {
    final templates = catalog.isLoading || catalog.hasError
        ? null
        : catalog.value?.templates;
    cache.retainKeys({
      for (final design in templates ?? <AiSlideDesign>[])
        if (design.theme.centerRecipe?.thumbnail != null)
          _thumbnailKey(design.theme.centerRecipe!),
    });
  }, fireImmediately: true);
  final retention = ref.keepAlive();
  Timer? release;
  ref.onCancel(() {
    release = Timer(const Duration(minutes: 2), retention.close);
  });
  ref.onResume(() {
    release?.cancel();
  });
  ref.onDispose(() {
    release?.cancel();
    cache.dispose();
  });
  return cache;
}

@riverpod
FutureOr<ui.Image?> centerSlideThumbnail(Ref ref, CenterSlideRecipe recipe) {
  final actions = ref.watch(centerSlideTemplateActionsProvider);
  _requireCatalog(ref);
  final cache = ref.watch(centerSlideImageCacheProvider);
  final key = _thumbnailKey(recipe);
  final catalog = ref.read(centerSlideCatalogProvider).value;
  if (!(catalog?.templates.any(
        (design) => design.theme.centerRecipe == recipe,
      ) ??
      false)) {
    throw const AiSlidesFailure('센터 템플릿이 변경되었습니다. 다시 선택해 주세요.');
  }
  ui.Image? retain(ui.Image? image) {
    if (!ref.mounted) {
      image?.dispose();
      return null;
    }
    if (image != null) ref.onDispose(image.dispose);
    return image;
  }

  final cached = cache.peek(key);
  if (cached != null) return retain(cached);
  return cache.load(key, () => actions.loadThumbnail(recipe)).then(retain);
}

String _thumbnailKey(CenterSlideRecipe recipe) =>
    '${recipe.templateId}/${recipe.revision}/${recipe.thumbnail?.sha256}';
