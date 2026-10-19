import 'dart:typed_data';

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

@riverpod
Future<Uint8List> centerSlidePreview(Ref ref, AiSlideDraft draft) async {
  final actions = ref.watch(centerSlideTemplateActionsProvider);
  final catalog = ref.watch(centerSlideCatalogProvider);
  if (catalog.isLoading ||
      catalog.hasError ||
      (catalog.value?.revision ?? 0) == 0) {
    throw const AiSlidesFailure(
      '센터 템플릿 권한을 확인하고 있어요.',
      code: 'center_authority_unavailable',
    );
  }
  return actions.renderDraft(draft);
}
