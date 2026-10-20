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

typedef CenterSlideDraftRenderer = Future<Uint8List> Function(
  CenterSlideRecipe recipe,
  AiSlideDraft draft, {
  Uint8List? backgroundBytes,
});

// One full-resolution result at most; larger PNGs are returned without retention.
const centerSlideRenderedCacheMaxBytes = 8 * 1024 * 1024;
const _rendererVersion = 1;
typedef _RenderKey = ({int version, int generation, AiSlideDraft draft});

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
  CenterSlideTemplateRepositoryImpl(
    this.source, {
    CenterSlideDraftRenderer? renderer,
  }) : _renderer = renderer ?? renderCenterSlide {
    source.addAuthorityInvalidationListener(_clearRendered);
  }
  final CenterSlideCatalogDataSource source;
  final CenterSlideDraftRenderer _renderer;
  _RenderKey? _cachedKey, _pendingKey;
  Uint8List? _cachedPng;
  Future<Uint8List>? _pending;

  void _clearRendered() {
    _cachedKey = null;
    _cachedPng = null;
    _pendingKey = null;
    _pending = null;
  }

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
    // Both preview and Add pass through this guard. A byte-cache hit never
    // grants access: use the current account, catalog authority and exact recipe.
    final int generation;
    try {
      generation = await source.authorizeRecipe(ownerId, recipe);
    } catch (_) {
      _clearRendered();
      rethrow;
    }
    final key = (
      version: _rendererVersion,
      generation: generation,
      draft: draft.copyWith(
        lines: List.unmodifiable(draft.lines),
        centerRecipe: recipe.copyWith(fields: List.unmodifiable(recipe.fields)),
      ),
    );
    final cached = _cachedPng;
    if (_cachedKey == key && cached != null) {
      source.ensureRecipeAuthorized(ownerId, recipe, generation: generation);
      return Uint8List.fromList(cached);
    }
    // Share a preview still rendering when Add is tapped. Only the newest
    // request can retain a result; older completions cannot overwrite its cache.
    _cachedKey = null;
    _cachedPng = null;
    final request = _pendingKey == key && _pending != null
        ? _pending!
        : _render(ownerId, key.draft, key.draft.centerRecipe!, generation);
    _pendingKey = key;
    _pending = request;
    try {
      final rendered = await request;
      source.ensureRecipeAuthorized(ownerId, recipe, generation: generation);
      if (identical(_pending, request) &&
          rendered.length <= centerSlideRenderedCacheMaxBytes) {
        _cachedKey = key;
        _cachedPng = Uint8List.fromList(rendered);
      }
      return Uint8List.fromList(rendered);
    } finally {
      if (identical(_pending, request)) {
        _pendingKey = null;
        _pending = null;
      }
    }
  }

  Future<Uint8List> _render(
    String ownerId,
    AiSlideDraft draft,
    CenterSlideRecipe recipe,
    int generation,
  ) async {
    final background = await source.loadBackground(ownerId, recipe);
    source.ensureRecipeAuthorized(ownerId, recipe, generation: generation);
    try {
      final rendered = await _renderer(
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
