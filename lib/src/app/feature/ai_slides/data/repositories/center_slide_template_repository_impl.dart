import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/center_slide_catalog_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/center_slide_template_repository.dart';

part 'center_slide_template_repository_impl.g.dart';

@riverpod
CenterSlideTemplateRepository centerSlideTemplateRepository(
  Ref ref,
  String ownerId,
  String centerId,
  Object lifetime,
) {
  final auth = ref.watch(firebaseClientAuthProvider);
  final firestore = FirebaseFirestore.instanceFor(app: auth.app);
  final document = firestore.doc(
    'centers/$centerId/slideTemplateCatalog/current',
  );
  final source = CenterSlideCatalogDataSource(
    projectId: auth.app.options.projectId,
    ownerId: ownerId,
    centerId: centerId,
    bucket: auth.app.options.storageBucket ?? '',
    isCurrentIdentity: () =>
        ref.mounted &&
        auth.currentUser?.uid == ownerId &&
        auth.currentUser?.isAnonymous == false,
    idToken: () async {
      final user = auth.currentUser;
      return user == null ? null : await user.getIdToken();
    },
    documents: () => document
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => CenterSlideDocument(
            data: snapshot.data(),
            fromCache: snapshot.metadata.isFromCache,
          ),
        ),
    readServerDocument: () async {
      final snapshot = await document.get(
        const GetOptions(source: Source.server),
      );
      return CenterSlideDocument(
        data: snapshot.data(),
        fromCache: snapshot.metadata.isFromCache,
      );
    },
    client: http.Client(),
  );
  ref.onDispose(source.clear);
  return CenterSlideTemplateRepositoryImpl(source);
}

class CenterSlideTemplateRepositoryImpl
    implements CenterSlideTemplateRepository {
  const CenterSlideTemplateRepositoryImpl(this.source);
  final CenterSlideCatalogDataSource source;
  @override
  Stream<CenterSlideCatalog> watchCatalog(String ownerId, String centerId) =>
      source.watchCatalog(ownerId, centerId);
  @override
  Future<Uint8List?> loadBackground(String ownerId, CenterSlideRecipe recipe) =>
      source.loadBackground(ownerId, recipe);
  @override
  Future<Uint8List> renderDraft(String ownerId, AiSlideDraft draft) async {
    final recipe = draft.centerRecipe;
    if (recipe == null) {
      throw const AiSlidesFailure(
        '센터 템플릿을 확인해 주세요.',
        code: 'center_recipe_missing',
      );
    }
    source.ensureCurrent(ownerId, requestedCenter: recipe.centerId);
    final background = await source.loadBackground(ownerId, recipe);
    final generation = source.authorityGeneration;
    source.ensureRecipeAuthorized(ownerId, recipe, generation: generation);
    try {
      final rendered = await renderCenterSlide(
        recipe,
        draft,
        backgroundBytes: background,
      );
      source.ensureRecipeAuthorized(ownerId, recipe, generation: generation);
      return rendered;
    } on FormatException catch (error) {
      throw AiSlidesFailure(error.message, code: 'center_recipe_content');
    }
  }

  @override
  void clear() => source.clear();
}
