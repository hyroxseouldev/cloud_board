import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

const homeThumbnailMaxBytes = 64 * 1024;
const homeThumbnailRendition = 'home-v1';

typedef HomeThumbnailLoad = Future<Uint8List?> Function(String source);

/// A home/account-scoped, bounded compressed-byte cache. No disk writes,
/// all-list preload or retained playback bytes. Source includes asset generation.
final homeThumbnailCacheProvider = Provider.autoDispose
    .family<HomeThumbnailCache, String>((ref, ownerId) {
      final user = ref.watch(authStateProvider).value;
      final loader = HomeThumbnailLoader(ownerId);
      final cache = HomeThumbnailCache(
        user?.id == ownerId ? loader.load : (_) async => null,
      );
      ref.onDispose(() {
        cache.dispose();
        loader.dispose();
      });
      return cache;
    });

class HomeThumbnailRequest {
  HomeThumbnailRequest(this.future, this.release);
  final Future<Uint8List?> future;
  final VoidCallback release;
}

class HomeThumbnailCache {
  HomeThumbnailCache(this.loadBytes);
  final HomeThumbnailLoad loadBytes;
  final _entries = <String, Future<Uint8List?>>{};
  final _visible = <String, int>{};
  Future<void> _queue = Future.value();
  bool _disposed = false;
  int _queued = 0;

  HomeThumbnailRequest watch(String source, DateTime revision) {
    final key = isManagedImageSource(source) ? source : '$source|$revision';
    _visible[key] = (_visible[key] ?? 0) + 1;
    return HomeThumbnailRequest(
      load(source, cacheKey: key, isVisible: () => (_visible[key] ?? 0) > 0),
      () {
        final count = _visible[key] ?? 0;
        if (count <= 1) {
          _visible.remove(key);
        } else {
          _visible[key] = count - 1;
        }
      },
    );
  }

  Future<Uint8List?> load(
    String source, {
    String? cacheKey,
    bool Function()? isVisible,
  }) {
    if (_disposed || source.isEmpty) return Future.value(null);
    final key = cacheKey ?? source;
    final old = _entries.remove(key);
    if (old != null) {
      _entries[key] = old;
      return old;
    }
    // One active request and at most eight visible cells waiting, never a page
    // of original-image requests. Miss/error has a stable placeholder this visit.
    if (_queued >= 8) return Future.value(null);
    _queued++;
    var cancelled = false;
    late Future<Uint8List?> future;
    future = _queue
        .then<Uint8List?>((_) async {
          if (_disposed || isVisible?.call() == false) {
            cancelled = true;
            return null;
          }
          try {
            final bytes = await loadBytes(source);
            return !_disposed &&
                    bytes != null &&
                    bytes.length <= homeThumbnailMaxBytes
                ? bytes
                : null;
          } catch (_) {
            return null;
          }
        })
        .whenComplete(() {
          _queued--;
          if (cancelled && identical(_entries[key], future)) {
            _entries.remove(key);
          }
        });
    _queue = future.then<void>((_) {});
    _entries[key] = future;
    while (_entries.length > 32) {
      _evict(_entries.remove(_entries.keys.first)!);
    }
    return future;
  }

  void _evict(Future<Uint8List?> entry) {
    unawaited(
      entry.then((bytes) async {
        if (bytes != null) {
          await ResizeImage(MemoryImage(bytes), width: 192).evict();
        }
      }),
    );
  }

  void dispose() {
    _disposed = true;
    for (final entry in _entries.values) {
      _evict(entry);
    }
    _entries.clear();
    _visible.clear();
  }
}

/// Only the authenticated managed rendition can cause network I/O. Missing,
/// unsupported and old-server responses never fall back to an original GET.
class HomeThumbnailLoader {
  HomeThumbnailLoader(this.ownerId);
  final String ownerId;
  final _requests = <http.Client>{};
  bool _disposed = false;

  Future<Uint8List?> load(String source) async {
    if (_disposed || ownerId.isEmpty) return null;
    if (isManagedImageSource(source)) return _managed(source);
    if (source.startsWith('http://') || source.startsWith('https://')) {
      // Legacy native disk cache reuse is safe only for the current owner's
      // canonical Storage namespace, with a live TTL and already-small bytes.
      final uri = Uri.tryParse(source);
      if (kIsWeb ||
          uri?.host != 'firebasestorage.googleapis.com' ||
          uri!.pathSegments.length != 5 ||
          uri.pathSegments[0] != 'v0' ||
          uri.pathSegments[3] != 'o' ||
          !uri.pathSegments.last.startsWith('users/$ownerId/')) {
        return null;
      }
      final cached = await CachedNetworkImageProvider.defaultCacheManager
          .getFileFromCache(source);
      if (cached == null ||
          cached.validTill.isBefore(DateTime.now()) ||
          await cached.file.length() > homeThumbnailMaxBytes) {
        return null;
      }
      return _smallStill(await cached.file.readAsBytes());
    }
    // Bound before base64 decoding; no copy of a full embedded original.
    if (source.length > homeThumbnailMaxBytes * 4 ~/ 3 + 128) return null;
    try {
      return _smallStill(WorkoutImageSource.decode(source).bytes);
    } on FormatException {
      return null;
    }
  }

  Uint8List? _smallStill(Uint8List bytes) {
    if (_disposed ||
        bytes.length < 24 ||
        bytes.length > homeThumbnailMaxBytes) {
      return null;
    }
    try {
      final type = WorkoutImageSource.identify(bytes).contentType;
      final img.Decoder decoder;
      if (type == 'image/png') {
        decoder = img.PngDecoder();
      } else if (type == 'image/jpeg') {
        decoder = img.JpegDecoder();
      } else {
        return null;
      }
      final info = decoder.startDecode(bytes);
      return info != null &&
              info.numFrames == 1 &&
              info.width > 0 &&
              info.height > 0 &&
              info.width * info.height <= 4 * 1024 * 1024
          ? bytes
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _managed(String source) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser?.uid != ownerId) return null;
    final usage = ImageUsageDataSource.forApp(auth.app, auth: auth);
    final client = http.Client();
    _requests.add(client);
    try {
      final uri = homeThumbnailUri(source, auth.app.options.projectId);
      if (uri == null) return null;
      // Explicit owner preview: no gate read, admission or class-start counter.
      final lease = await usage.invoke('cloudboardMediaLease', {
        'action': 'issue',
        'requestId': createEventId(),
        'assetIds': [uri.queryParameters['assetId']],
        'admissionId': null,
        'sessionId': null,
        'purpose': 'preview',
      });
      final assets = lease['assets'];
      if (assets is! List ||
          !assets.any(
            (asset) =>
                asset is Map &&
                asset['source'] == source &&
                asset['generation'] == uri.queryParameters['v'],
          )) {
        return null;
      }
      final token = await usage.token();
      usage.ensureCurrent();
      if (_disposed || token.isEmpty) return null;
      final response = await client
          .send(
            http.Request('GET', uri)
              ..followRedirects = false
              ..headers.addAll({
                'Authorization': 'Bearer $token',
                'X-CloudBoard-Media-Lease': lease['leaseId'] as String,
              }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 ||
          response.headers['content-type']?.split(';').first != 'image/jpeg' ||
          (response.contentLength ?? homeThumbnailMaxBytes + 1) >
              homeThumbnailMaxBytes) {
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 10),
      )) {
        usage.ensureCurrent();
        if (_disposed || bytes.length + chunk.length > homeThumbnailMaxBytes) {
          return null;
        }
        bytes.add(chunk);
      }
      usage.ensureCurrent();
      return _smallStill(bytes.takeBytes());
    } finally {
      usage.dispose();
      _requests.remove(client);
      client.close();
    }
  }

  void dispose() {
    _disposed = true;
    for (final client in _requests) {
      client.close();
    }
    _requests.clear();
  }
}

/// No arbitrary CDN/source URL receives an auth token. The old canonical source
/// remains unchanged; rendition is an optional body endpoint query only.
Uri? homeThumbnailUri(String source, String projectId) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.queryParameters.keys.any((key) => key != 'assetId' && key != 'v') ||
      uri.queryParametersAll.values.any((values) => values.length != 1) ||
      !RegExp(r'^[A-Za-z0-9_-]{1,120}$')
          .hasMatch(uri.queryParameters['assetId'] ?? '') ||
      !RegExp(r'^\d+$').hasMatch(uri.queryParameters['v'] ?? '')) {
    return null;
  }
  final remote =
      projectId == 'cloud-board-development' &&
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.host == 'asia-northeast3-$projectId.cloudfunctions.net' &&
      uri.path == '/cloudboardMedia';
  final local =
      projectId.startsWith('demo-') &&
      uri.scheme == 'http' &&
      const ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host) &&
      uri.path == '/$projectId/asia-northeast3/cloudboardMedia';
  return remote || local
      ? uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'rendition': homeThumbnailRendition,
          },
        )
      : null;
}
