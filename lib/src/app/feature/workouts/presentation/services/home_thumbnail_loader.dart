import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

typedef HomeThumbnailLoad = Future<Uint8List?> Function(
  String source, {
  String? workoutId,
  DateTime? updatedAt,
});

/// A home/account-scoped, bounded compressed-byte cache. No disk writes,
/// all-list preload or retained playback bytes. Source includes asset generation.
final homeThumbnailCacheProvider = Provider.autoDispose
    .family<HomeThumbnailCache, String>((ref, ownerId) {
      final user = ref.watch(authStateProvider).value;
      final loader = HomeThumbnailLoader(ownerId);
      final cache = HomeThumbnailCache(
        user?.id == ownerId
            ? loader.load
            : (_, {workoutId, updatedAt}) async => null,
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

  HomeThumbnailRequest watch(
    String source,
    DateTime revision, {
    String? workoutId,
  }) {
    final key = isManagedImageSource(source)
        ? source
        : '$workoutId|$source|$revision';
    _visible[key] = (_visible[key] ?? 0) + 1;
    return HomeThumbnailRequest(
      load(
        source,
        cacheKey: key,
        workoutId: workoutId,
        updatedAt: revision,
        isVisible: () => (_visible[key] ?? 0) > 0,
      ),
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
    String? workoutId,
    DateTime? updatedAt,
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
            final bytes = await loadBytes(
              source,
              workoutId: workoutId,
              updatedAt: updatedAt,
            );
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

/// Only authenticated, bounded home renditions can cause network I/O. Missing,
/// unsupported and old-server responses never fall back to an original GET.
class HomeThumbnailLoader {
  HomeThumbnailLoader(
    this.ownerId, {
    this.usageFactory,
    http.Client Function()? clientFactory,
    this.demoEndpoint,
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final ImageUsageDataSource Function()? usageFactory;
  final http.Client Function() _clientFactory;

  /// Explicit test/demo configuration only; never inferred from an image URL.
  final Uri? demoEndpoint;

  ImageUsageDataSource? _usage() {
    final factory = usageFactory;
    if (factory != null) return factory();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser?.uid != ownerId ||
        auth.currentUser?.isAnonymous == true) {
      return null;
    }
    return ImageUsageDataSource.forApp(auth.app, auth: auth);
  }

  final String ownerId;
  final _requests = <http.Client>{};
  bool _disposed = false;

  Future<Uint8List?> load(
    String source, {
    String? workoutId,
    DateTime? updatedAt,
  }) async {
    if (_disposed || ownerId.isEmpty) return null;
    if (isManagedImageSource(source)) return _managed(source);
    if (source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('gs://')) {
      // A source token is never forwarded: the server resolves the authorized
      // first image from the workout and validates this exact summary hash.
      if (!homeLegacySourceOwned(source, ownerId) ||
          workoutId == null ||
          updatedAt == null) {
        return null;
      }
      return _legacy(source, workoutId, updatedAt);
    }
    // Bound before base64 decoding; no copy of a full embedded original.
    if (source.length > homeThumbnailMaxBytes * 4 ~/ 3 + 128) return null;
    try {
      return _smallStill(WorkoutImageSource.decode(source).bytes);
    } on FormatException {
      return null;
    }
  }

  Uint8List? _smallStill(Uint8List bytes, {int? maxDimension}) {
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
              (maxDimension == null ||
                  (info.width <= maxDimension &&
                      info.height <= maxDimension)) &&
              info.width * info.height <= 4 * 1024 * 1024
          ? bytes
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _managed(String source) async {
    final usage = _usage();
    if (usage == null) return null;
    final client = _clientFactory();
    _requests.add(client);
    try {
      final uri = homeThumbnailUri(source, usage.projectId);
      if (uri == null || usage.actorId != ownerId) return null;
      usage.ensureCurrent();
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
      return await _download(
        client,
        usage,
        uri,
        token,
        leaseId: lease['leaseId'] as String,
      );
    } finally {
      usage.dispose();
      _requests.remove(client);
      client.close();
    }
  }

  Future<Uint8List?> _legacy(
    String source,
    String workoutId,
    DateTime updatedAt,
  ) async {
    final usage = _usage();
    if (usage == null) return null;
    final client = _clientFactory();
    _requests.add(client);
    try {
      final uri = homeLegacyThumbnailUri(
        source: source,
        ownerId: ownerId,
        workoutId: workoutId,
        updatedAt: updatedAt,
        projectId: usage.projectId,
        demoEndpoint: demoEndpoint,
      );
      if (uri == null || usage.actorId != ownerId) return null;
      usage.ensureCurrent();
      final token = await usage.token();
      usage.ensureCurrent();
      if (_disposed || token.isEmpty) return null;
      return await _download(client, usage, uri, token);
    } finally {
      usage.dispose();
      _requests.remove(client);
      client.close();
    }
  }

  Future<Uint8List?> _download(
    http.Client client,
    ImageUsageDataSource usage,
    Uri uri,
    String token, {
    String? leaseId,
  }) async {
    final response = await client
        .send(
          http.Request('GET', uri)
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'X-CloudBoard-Media-Lease': ?leaseId,
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
    if (bytes.length != response.contentLength) return null;
    final body = bytes.takeBytes();
    if (body.length < 3 ||
        body[0] != 0xff ||
        body[1] != 0xd8 ||
        body[2] != 0xff) {
      return null;
    }
    return _smallStill(body, maxDimension: 192);
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

/// Reject arbitrary origins and another owner's Storage namespace before auth.
bool homeLegacySourceOwned(String source, String ownerId) {
  final uri = Uri.tryParse(source);
  if (ownerId.isEmpty ||
      uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final String object;
  if (uri.scheme == 'gs' &&
      uri.host.isNotEmpty &&
      !uri.hasPort &&
      !uri.hasQuery) {
    object = uri.pathSegments.join('/');
  } else if (uri.scheme == 'https' &&
      uri.host == 'firebasestorage.googleapis.com' &&
      uri.port == 443 &&
      uri.pathSegments.length == 5 &&
      uri.pathSegments[0] == 'v0' &&
      uri.pathSegments[1] == 'b' &&
      uri.pathSegments[3] == 'o' &&
      !uri.queryParametersAll.values.any((values) => values.length != 1) &&
      !uri.queryParameters.keys.any((key) => key != 'alt' && key != 'token') &&
      uri.queryParameters['alt'] == 'media') {
    object = uri.pathSegments.last;
  } else {
    return false;
  }
  final prefix = 'users/$ownerId/';
  if (!object.startsWith(prefix)) return false;
  final relative = object.substring(prefix.length);
  return RegExp(r'^workouts/[A-Za-z0-9_-]{1,128}/images/[a-f0-9]{64}$')
          .hasMatch(relative) ||
      RegExp(
        r'^workouts/[A-Za-z0-9_-]{1,128}/modules/[A-Za-z0-9_-]{1,128}/background$',
      ).hasMatch(relative);
}

Uri? homeLegacyThumbnailUri({
  required String source,
  required String ownerId,
  required String workoutId,
  required DateTime updatedAt,
  required String projectId,
  Uri? demoEndpoint,
}) {
  if (!homeLegacySourceOwned(source, ownerId) ||
      !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(workoutId) ||
      updatedAt.millisecondsSinceEpoch < 0 ||
      updatedAt.millisecondsSinceEpoch > 253402300799999) {
    return null;
  }
  final sourceUri = Uri.parse(source);
  if (!{'$projectId.appspot.com', '$projectId.firebasestorage.app'}.contains(
    sourceUri.scheme == 'gs' ? sourceUri.host : sourceUri.pathSegments[2],
  )) {
    return null;
  }
  final Uri endpoint;
  if (projectId == 'cloud-board-development') {
    endpoint = Uri.https(
      'asia-northeast3-$projectId.cloudfunctions.net',
      '/cloudboardMedia',
    );
  } else if (projectId.startsWith('demo-') &&
      demoEndpoint != null &&
      demoEndpoint.scheme == 'http' &&
      const [
        '127.0.0.1',
        'localhost',
        '10.0.2.2',
      ].contains(demoEndpoint.host) &&
      demoEndpoint.userInfo.isEmpty &&
      !demoEndpoint.hasQuery &&
      !demoEndpoint.hasFragment &&
      demoEndpoint.path == '/$projectId/asia-northeast3/cloudboardMedia') {
    endpoint = demoEndpoint;
  } else {
    return null;
  }
  return endpoint.replace(
    queryParameters: {
      'rendition': homeThumbnailRendition,
      'workoutId': workoutId,
      'sourceHash': sha256.convert(utf8.encode(source)).toString(),
      'updatedAtMs': updatedAt.millisecondsSinceEpoch.toString(),
    },
  );
}
