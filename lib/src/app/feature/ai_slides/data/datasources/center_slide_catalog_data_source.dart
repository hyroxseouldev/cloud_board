import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

const centerSlideAuthorityLifetime = Duration(hours: 6);
const centerSlideBackgroundMaxBytes = 10 * 1024 * 1024;
const _assetCacheBudget = 20 * 1024 * 1024;

class CenterSlideDocument {
  const CenterSlideDocument({required this.data, required this.fromCache});
  final Map<String, dynamic>? data;
  final bool fromCache;
}

/// A single project/account/center owns this source for its entire lifetime.
/// SDK cache events cannot establish or extend authorization. No private image
/// or download token is written to disk or to the public image cache.
class CenterSlideCatalogDataSource {
  CenterSlideCatalogDataSource({
    required this.projectId,
    required this.ownerId,
    required this.centerId,
    required this.bucket,
    required this.isCurrentIdentity,
    required this.idToken,
    required this.documents,
    required this.readServerDocument,
    required this.client,
    this.appCheckToken,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final String projectId, ownerId, centerId, bucket;
  final bool Function() isCurrentIdentity;
  final Future<String?> Function() idToken;
  final Future<String?> Function()? appCheckToken;
  final Stream<CenterSlideDocument> Function() documents;
  final Future<CenterSlideDocument> Function() readServerDocument;
  final http.Client client;
  final DateTime Function() now;
  final _listeners = <StreamController<CenterSlideCatalog>>{};
  final _authorityInvalidationListeners = <void Function()>{};
  final _assets = <String, Uint8List>{};
  final _assetRequests = <String, Future<Uint8List>>{};
  int _assetBytes = 0, _generation = 0;
  bool _disposed = false;
  CenterSlideCatalogModel? _catalog;
  String? _catalogFingerprint;
  DateTime? _authorizedUntil;
  Timer? _expiry;
  StreamSubscription<CenterSlideDocument>? _subscription;
  Future<void>? _authorityRead;

  String get cacheScope => '$projectId/$ownerId/$centerId';
  int get authorityGeneration => _generation;
  // Derived private data (for example a rendered preview) must expire with
  // catalog/permission changes, even when no further render is requested.
  void addAuthorityInvalidationListener(void Function() listener) =>
      _authorityInvalidationListeners.add(listener);

  void _invalidateAuthorityGeneration() {
    _generation++;
    for (final listener in _authorityInvalidationListeners.toList()) {
      listener();
    }
  }

  bool get _authorized =>
      _catalog != null &&
      _authorizedUntil != null &&
      now().isBefore(_authorizedUntil!);

  void ensureCurrent(
    String requestedOwner, {
    String? requestedCenter,
    int? generation,
  }) {
    if (_disposed ||
        !isCurrentIdentity() ||
        requestedOwner != ownerId ||
        (requestedCenter != null && requestedCenter != centerId) ||
        (generation != null && generation != _generation)) {
      throw const AiSlidesFailure(
        '계정 또는 센터가 변경되었습니다.',
        code: 'center_scope_changed',
      );
    }
  }

  void ensureAuthorized(
    String requestedOwner, {
    required String requestedCenter,
    int? generation,
  }) {
    ensureCurrent(
      requestedOwner,
      requestedCenter: requestedCenter,
      generation: generation,
    );
    if (!_authorized) {
      throw const AiSlidesFailure(
        '센터 권한을 다시 확인해 주세요.',
        code: 'center_authority_expired',
      );
    }
  }

  Stream<CenterSlideCatalog> watchCatalog(
    String requestedOwner,
    String requestedCenter,
  ) {
    ensureCurrent(requestedOwner, requestedCenter: requestedCenter);
    late StreamController<CenterSlideCatalog> controller;
    controller = StreamController<CenterSlideCatalog>(
      onListen: () {
        try {
          ensureCurrent(requestedOwner, requestedCenter: requestedCenter);
          _listeners.add(controller);
          controller.add(
            _authorized
                ? _catalog!.toEntity()
                : emptyCenterSlideCatalog(centerId),
          );
          _subscription ??= documents().listen(
            _receive,
            onError: _receiveError,
          );
        } catch (_) {
          controller.add(emptyCenterSlideCatalog(centerId));
        }
      },
      onCancel: () {
        _listeners.remove(controller);
        if (_listeners.isEmpty) {
          final previous = _subscription;
          _subscription = null;
          if (previous != null) unawaited(previous.cancel());
        }
      },
    );
    return controller.stream;
  }

  void _notify() {
    if (_disposed || !isCurrentIdentity()) return;
    final value = _authorized
        ? _catalog!.toEntity()
        : emptyCenterSlideCatalog(centerId);
    for (final listener in _listeners.toList()) {
      if (!listener.isClosed) listener.add(value);
    }
  }

  void _receive(CenterSlideDocument document) {
    if (_disposed || !isCurrentIdentity()) return;
    if (document.fromCache) {
      // Only our last successful server result may survive a temporary outage.
      if (!_authorized && _catalog != null) _forget();
      _notify();
      return;
    }
    if (document.data == null) {
      _forget();
      _notify();
      return;
    }
    try {
      final model = CenterSlideCatalogModel.fromJson(
        document.data!,
        centerId: centerId,
      );
      // Never replace the current catalog with a late lower-revision snapshot.
      if (_catalog == null || model.revision >= _catalog!.revision) {
        final fingerprint = jsonEncode(model.toJson());
        if (fingerprint != _catalogFingerprint) {
          _invalidateAuthorityGeneration();
          _assets.clear();
          _assetRequests.clear();
          _assetBytes = 0;
          _catalogFingerprint = fingerprint;
        }
        _catalog = model;
      }
      _authorizedUntil = now().add(centerSlideAuthorityLifetime);
      _expiry?.cancel();
      _expiry = Timer(centerSlideAuthorityLifetime, () {
        if (!_authorized) {
          _forget();
          _notify();
        }
      });
      _notify();
    } catch (_) {
      _forget();
      _notify();
    }
  }

  void _receiveError(Object error, [StackTrace? stack]) {
    if (_disposed) return;
    if (_denied(error) || !_authorized) _forget();
    _notify();
  }

  bool _denied(Object error) =>
      error is FirebaseException &&
      const {'permission-denied', 'unauthenticated'}.contains(error.code);

  void _forget() {
    _invalidateAuthorityGeneration();
    _catalog = null;
    _catalogFingerprint = null;
    _authorizedUntil = null;
    _expiry?.cancel();
    _expiry = null;
    _assets.clear();
    _assetRequests.clear();
    _assetBytes = 0;
  }

  Future<void> _requireAuthority() async {
    ensureCurrent(ownerId);
    if (_authorized) return;
    if (_authorityRead != null) return _authorityRead!;
    if (_catalog != null) _forget();
    final generation = _generation;
    final request = () async {
      try {
        final document = await readServerDocument().timeout(
          const Duration(seconds: 15),
        );
        ensureCurrent(ownerId, generation: generation);
        if (document.fromCache) {
          throw const AiSlidesFailure(
            '센터 권한을 확인하지 못했습니다.',
            code: 'center_authority_unavailable',
          );
        }
        _receive(document);
        ensureCurrent(ownerId);
        if (!_authorized) {
          throw const AiSlidesFailure(
            '센터 템플릿 권한을 확인해 주세요.',
            code: 'center_catalog_unavailable',
          );
        }
      } catch (error) {
        if (!_disposed && (_denied(error) || !_authorized)) {
          _forget();
          _notify();
        }
        rethrow;
      }
    }();
    _authorityRead = request;
    try {
      await request;
    } finally {
      if (identical(_authorityRead, request)) _authorityRead = null;
    }
  }

  void ensureRecipeAuthorized(
    String requestedOwner,
    CenterSlideRecipe recipe, {
    int? generation,
  }) {
    ensureAuthorized(
      requestedOwner,
      requestedCenter: recipe.centerId,
      generation: generation,
    );
    if (!_catalog!.entries.any(
      (entry) => entry.published && entry.recipe == recipe,
    )) {
      throw const AiSlidesFailure(
        '센터 템플릿이 변경되었습니다. 다시 선택해 주세요.',
        code: 'center_recipe_unavailable',
      );
    }
  }

  Future<int> authorizeRecipe(
    String requestedOwner,
    CenterSlideRecipe recipe,
  ) async {
    ensureCurrent(requestedOwner, requestedCenter: recipe.centerId);
    if (validateCenterSlideRecipe(recipe) != null) {
      throw const AiSlidesFailure(
        '센터 템플릿 형식을 확인해 주세요.',
        code: 'center_recipe_invalid',
      );
    }
    await _requireAuthority();
    ensureRecipeAuthorized(requestedOwner, recipe);
    return _generation;
  }

  Future<Uint8List?> loadBackground(
    String requestedOwner,
    CenterSlideRecipe recipe,
  ) async {
    final generation = await authorizeRecipe(requestedOwner, recipe);
    final path = recipe.backgroundPath;
    if (path == null) return null;
    final key = '$cacheScope/$path';
    final cached = _assets.remove(key);
    if (cached != null) {
      _assets[key] = cached;
      return Uint8List.fromList(cached);
    }
    // Initial card, editor and confirmation may request the same private PNG
    // concurrently. Share its transfer only within this authorization generation.
    final requestKey = '$generation/$key';
    final pending = _assetRequests[requestKey] ??= _fetchBackground(
      requestedOwner,
      recipe,
      path: path,
      key: key,
      generation: generation,
    );
    try {
      final result = await pending;
      ensureRecipeAuthorized(requestedOwner, recipe, generation: generation);
      return Uint8List.fromList(result);
    } finally {
      if (identical(_assetRequests[requestKey], pending)) {
        _assetRequests.remove(requestKey);
      }
    }
  }

  Future<Uint8List> _fetchBackground(
    String requestedOwner,
    CenterSlideRecipe recipe, {
    required String path,
    required String key,
    required int generation,
  }) async {
    final token = await idToken();
    ensureCurrent(
      requestedOwner,
      requestedCenter: recipe.centerId,
      generation: generation,
    );
    if (token == null ||
        token.isEmpty ||
        !RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(bucket)) {
      throw const AiSlidesFailure(
        '센터 이미지 접근 권한을 확인해 주세요.',
        code: 'center_asset_unauthenticated',
      );
    }
    final attestation = await appCheckToken?.call();
    ensureCurrent(
      requestedOwner,
      requestedCenter: recipe.centerId,
      generation: generation,
    );
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(path)}?alt=media',
    );
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Authorization'] = 'Firebase $token';
    if (attestation != null && attestation.isNotEmpty) {
      request.headers['X-Firebase-AppCheck'] = attestation;
    }
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    try {
      ensureRecipeAuthorized(requestedOwner, recipe, generation: generation);
    } catch (_) {
      await response.stream.listen((_) {}).cancel();
      rethrow;
    }
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      if (response.statusCode == 401 || response.statusCode == 403) {
        _forget();
        _notify();
      }
      throw const AiSlidesFailure(
        '센터 이미지를 불러오지 못했습니다.',
        code: 'center_asset_unavailable',
      );
    }
    if ((response.contentLength ?? 0) > centerSlideBackgroundMaxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const AiSlidesFailure(
        '센터 이미지 크기를 확인해 주세요.',
        code: 'center_asset_too_large',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 15),
    )) {
      ensureCurrent(
        requestedOwner,
        requestedCenter: recipe.centerId,
        generation: generation,
      );
      if (bytes.length + chunk.length > centerSlideBackgroundMaxBytes) {
        throw const AiSlidesFailure(
          '센터 이미지 크기를 확인해 주세요.',
          code: 'center_asset_too_large',
        );
      }
      bytes.add(chunk);
    }
    ensureCurrent(
      requestedOwner,
      requestedCenter: recipe.centerId,
      generation: generation,
    );
    if (!_authorized) {
      _forget();
      _notify();
      throw const AiSlidesFailure(
        '센터 권한을 다시 확인해 주세요.',
        code: 'center_authority_expired',
      );
    }
    ensureRecipeAuthorized(requestedOwner, recipe, generation: generation);
    final result = bytes.takeBytes();
    if (result.length < 24 ||
        result[0] != 137 ||
        result[1] != 80 ||
        result[2] != 78 ||
        result[3] != 71 ||
        result[4] != 13 ||
        result[5] != 10 ||
        result[6] != 26 ||
        result[7] != 10 ||
        sha256.convert(result).toString() != recipe.backgroundSha256 ||
        ByteData.sublistView(result).getUint32(16) != recipe.width ||
        ByteData.sublistView(result).getUint32(20) != recipe.height) {
      throw const AiSlidesFailure(
        '센터 이미지가 등록된 원본과 다릅니다.',
        code: 'center_asset_integrity',
      );
    }
    while (_assets.isNotEmpty &&
        _assetBytes + result.length > _assetCacheBudget) {
      _assetBytes -= _assets.remove(_assets.keys.first)!.length;
    }
    final previous = _assets.remove(key);
    if (previous != null) _assetBytes -= previous.length;
    _assets[key] = Uint8List.fromList(result);
    _assetBytes += result.length;
    return result;
  }

  void clear() {
    if (_disposed) return;
    _disposed = true;
    _forget();
    _authorityInvalidationListeners.clear();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    for (final listener in _listeners.toList()) {
      if (!listener.isClosed) unawaited(listener.close());
    }
    _listeners.clear();
    client.close();
  }
}
