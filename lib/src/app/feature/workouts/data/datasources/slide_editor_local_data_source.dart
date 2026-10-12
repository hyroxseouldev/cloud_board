import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';

class SlideEditorLocalDataSource {
  SlideEditorLocalDataSource({this._preferences, DraftAssetStore? assets})
    : assets = assets ?? createDraftAssetStore();

  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get preferences =>
      _preferences ??= SharedPreferencesAsync();
  final DraftAssetStore assets;

  // Serialize the entire asset/metadata operation, not only the final preference
  // write. A save followed by clear must never resurrect an in-flight draft.
  static Future<void>? _pending;
  _CachedDraftImage? _cachedImage;
  final _assetKeys = <String>{};

  Future<T> _ordered<T>(Future<T> Function() action) {
    final next = _pending?.then((_) => action()) ?? Future<T>.sync(action);
    final pending = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = pending;
    pending.whenComplete(() {
      if (identical(_pending, pending)) _pending = null;
    });
    return next;
  }

  Future<String?> read(String key) =>
      _ordered(() => preferences.getString('cloudboard.slide-editor.v1.$key'));

  Future<void> write(String key, String? value) => _ordered(() async {
    final storageKey = 'cloudboard.slide-editor.v1.$key';
    if (value == null) {
      await preferences.remove(storageKey);
    } else {
      await preferences.setString(storageKey, value);
    }
  });

  String _metadataKey(String key) => 'cloudboard.slide-editor.v2.draft.$key';
  String _legacyKey(String key) => 'cloudboard.slide-editor.v1.draft.$key';
  String _assetMarker(String key) => 'cloudboard.slide-editor.v2.assets.$key';
  String _assetScope(String key) => sha256.convert(utf8.encode(key)).toString();

  Future<Map<String, dynamic>?> readDraft(String key) => _ordered(() async {
    final stored = await preferences.getString(_metadataKey(key));
    if (stored == null) {
      final legacy = await preferences.getString(_legacyKey(key));
      if (legacy == null) {
        await _cleanup(key, null);
        return null;
      }
      final module = jsonDecode(legacy) as Map<String, dynamic>;
      // Retain the recoverable v1 document until both the asset and v2 metadata
      // are durable. A full disk or denied browser storage must not lose it.
      await _saveDraft(key, module);
      return module;
    }
    final document = jsonDecode(stored) as Map<String, dynamic>;
    if (document['version'] != 2) throw const FormatException('Draft version');
    final reference = document['image'] as Map<String, dynamic>?;
    if (document['cleared'] == true) {
      await _cleanup(key, null);
      return null;
    }
    final module = Map<String, dynamic>.from(document['module'] as Map);
    if (reference != null) {
      final bytes = await assets.read(
        _assetScope(key),
        reference['id'] as String,
      );
      if (bytes == null) {
        throw const FormatException('The draft image is missing');
      }
      final image = reference['encoding'] == 'base64'
          ? '${reference['prefix']}${base64Encode(bytes)}'
          : utf8.decode(bytes);
      module['imageUrl'] = image;
      _cachedImage = _CachedDraftImage(key, image, reference);
    } else if (_cachedImage?.key == key) {
      _cachedImage = null;
    }
    await _cleanup(key, reference);
    return module;
  });

  Future<void> writeDraft(String key, Map<String, dynamic> module) =>
      _ordered(() => _saveDraft(key, module));

  Future<void> _saveDraft(String key, Map<String, dynamic> module) async {
    final image = module['imageUrl'] as String? ?? '';
    Map<String, dynamic>? reference;
    if (image.startsWith('data:')) {
      final cached = _cachedImage;
      if (cached != null &&
          cached.key == key &&
          cached.image == image &&
          await assets.exists(
            _assetScope(key),
            cached.reference['id'] as String,
          )) {
        reference = cached.reference;
      } else {
        final comma = image.indexOf(',');
        final prefix = comma < 0 ? '' : image.substring(0, comma + 1);
        final base64 = prefix.endsWith(';base64,');
        final bytes = base64
            ? base64Decode(image.substring(comma + 1))
            : Uint8List.fromList(utf8.encode(image));
        reference = {
          'id': sha256.convert(bytes).toString(),
          'encoding': base64 ? 'base64' : 'uri',
          if (base64) 'prefix': prefix,
        };
        // The small intent marker lets a later process collect an asset written
        // just before its first metadata commit was interrupted.
        if (!_assetKeys.contains(key)) {
          await preferences.setBool(_assetMarker(key), true);
          _assetKeys.add(key);
        }
        final scope = _assetScope(key);
        final id = reference['id'] as String;
        if (!await assets.exists(scope, id)) {
          await assets.write(scope, id, bytes);
        }
        // Only one image is retained in memory; text/timer edits neither hash,
        // decode, nor rewrite that image. Clearing/recovery invalidates it.
        _cachedImage = _CachedDraftImage(key, image, reference);
      }
    }
    final metadata = {
      'version': 2,
      'module': {...module, if (reference != null) 'imageUrl': ''},
      'image': ?reference,
    };
    await preferences.setString(_metadataKey(key), jsonEncode(metadata));
    // Cleanup never runs before the metadata commit. Interrupted swaps leave
    // an orphan that the next read/save removes, never a dangling reference.
    await _cleanup(key, reference);
  }

  Future<void> clearDraft(String key) => _ordered(() async {
    // The tombstone also supersedes v1 if the process stops during cleanup.
    await preferences.setString(
      _metadataKey(key),
      jsonEncode({'version': 2, 'cleared': true}),
    );
    if (_cachedImage?.key == key) _cachedImage = null;
    await _cleanup(key, null);
  });

  Future<void> _cleanup(String key, Map<String, dynamic>? reference) async {
    try {
      await preferences.remove(_legacyKey(key));
      if (!_assetKeys.contains(key) &&
          await preferences.getBool(_assetMarker(key)) != true) {
        return;
      }
      await assets.retain(_assetScope(key), {
        if (reference != null) reference['id'] as String,
      });
      if (reference == null) {
        if (_cachedImage?.key == key) _cachedImage = null;
        await preferences.remove(_assetMarker(key));
        _assetKeys.remove(key);
      }
    } catch (_) {
      // Metadata is already authoritative. Retry non-destructive garbage
      // collection next time instead of reporting a successful save as failed.
    }
  }
}

class _CachedDraftImage {
  const _CachedDraftImage(this.key, this.image, this.reference);
  final String key, image;
  final Map<String, dynamic> reference;
}
