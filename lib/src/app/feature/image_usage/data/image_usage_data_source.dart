import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';

bool isManagedImageSource(String source) {
  final uri = Uri.tryParse(source);
  return uri != null && uri.pathSegments.contains('cloudboardMedia');
}

/// I/O is injectable so tests can prove admission/reservation precedes bodies.
class ImageUsageDataSource {
  static final _localOrigins = <String, Uri>{};

  /// Called by the existing debug emulator bootstrap. Never inferred from a
  /// missing environment or accepted for a development/production project.
  static void configureLocalEmulator(
    FirebaseApp app, {
    required String host,
    required int port,
  }) {
    if (!app.options.projectId.startsWith('demo-') ||
        !const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(host) ||
        port < 1 ||
        port > 65535) {
      throw ArgumentError(
        'A demo project and local Functions emulator are required',
      );
    }
    _localOrigins[app.name] = Uri(scheme: 'http', host: host, port: port);
  }

  ImageUsageDataSource({
    required this.projectId,
    required this.actorId,
    required this.currentActorId,
    required this.token,
    required this.call,
    required this.readGate,
    required this.send,
    required this.preferences,
  });
  factory ImageUsageDataSource.forApp(FirebaseApp app, {FirebaseAuth? auth}) {
    final clientAuth = auth ?? FirebaseAuth.instanceFor(app: app);
    final uid = clientAuth.currentUser?.uid;
    if (uid == null) throw const ImageUsageFailure('entitlement_unverified');
    final database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: cloudBoardRealtimeDatabaseUrl,
    );
    var identityValid = true;
    final identitySubscription = clientAuth.authStateChanges().listen((user) {
      if (user?.uid != uid) identityValid = false;
    });
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'asia-northeast3',
    );
    Future<String> ownerId() async {
      if (clientAuth.currentUser?.isAnonymous != true) return uid;
      return usageString(
        (await database.ref('displayAccess/$uid/ownerId').get()).value,
      );
    }

    final source = ImageUsageDataSource(
      projectId: app.options.projectId,
      actorId: uid,
      currentActorId: () => identityValid ? clientAuth.currentUser?.uid : null,
      token: () async => await clientAuth.currentUser?.getIdToken() ?? '',
      call: (endpoint, input) async {
        try {
          return usageMap(
            (await functions
                    .httpsCallable(
                      endpoint,
                      options: HttpsCallableOptions(
                        timeout: const Duration(seconds: 40),
                      ),
                    )
                    .call(input))
                .data,
          );
        } on FirebaseFunctionsException catch (error) {
          if (error.details is Map) {
            try {
              throw ImageUsageFailure.fromJson(error.details);
            } on FormatException {
              /* Safe service failure below. */
            }
          }
          throw const ImageUsageFailure('service_unavailable', retryable: true);
        }
      },
      readGate: () async {
        final owner = await ownerId();
        final gate = (await database.ref('users/$owner/usageGate').get()).value;
        if (gate is! Map) return gate;
        final phase = gate['phase'];
        if (phase != 'active' &&
            phase != 'committing' &&
            phase != 'preparing') {
          return gate;
        }
        final request =
            (await database
                    .ref('users/$owner/displayPreparation/request')
                    .get())
                .value;
        final images =
            request is Map && request['sessionId'] == gate['sessionId']
            ? request['images']
            : null;
        return {
          ...gate,
          '_imageSources': images is List
              ? images
              : images is Map
              ? images.values.toList()
              : <String>[],
        };
      },
      send: (request) async {
        final local = _localOrigins[app.name];
        if (app.options.projectId.startsWith('demo-') && local == null) {
          throw const ImageUsageFailure('service_unavailable', retryable: true);
        }
        if (local != null) {
          final original = request;
          request =
              http.Request(
                  original.method,
                  local.replace(
                    path:
                        '/${app.options.projectId}/asia-northeast3/${original.url.pathSegments.last}',
                    query: original.url.hasQuery ? original.url.query : null,
                  ),
                )
                ..headers.addAll(original.headers)
                ..bodyBytes = original.bodyBytes
                ..followRedirects = false;
        }
        final client = http.Client();
        try {
          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 40));
          return await http.Response.fromStream(response)
              .timeout(const Duration(seconds: 40));
        } finally {
          client.close();
        }
      },
      preferences: SharedPreferences.getInstance,
    );
    source._closeIdentity = () => unawaited(identitySubscription.cancel());
    return source;
  }
  final String projectId, actorId;
  final String? Function() currentActorId;
  final Future<String> Function() token;
  final Future<Map<String, dynamic>> Function(
    String endpoint,
    Map<String, dynamic> input,
  )
  call;
  final Future<Object?> Function() readGate;
  final Future<http.Response> Function(http.Request request) send;
  final Future<SharedPreferences> Function() preferences;
  bool _disposed = false;
  void Function()? _closeIdentity;
  void dispose() {
    _disposed = true;
    _closeIdentity?.call();
    _closeIdentity = null;
  }

  void ensureCurrent() {
    if (_disposed || currentActorId() != actorId) {
      throw const ImageUsageFailure('entitlement_unverified');
    }
  }

  Future<void> _store(SharedPreferences prefs, String key, String value) async {
    final stored = await prefs.setString(key, value);
    ensureCurrent();
    if (!stored) {
      throw const ImageUsageFailure('service_unavailable', retryable: true);
    }
  }

  Future<Map<String, dynamic>> invoke(
    String endpoint,
    Map<String, dynamic> input,
  ) async {
    ensureCurrent();
    try {
      final result = await call(endpoint, {'schemaVersion': 1, ...input});
      ensureCurrent();
      return result;
    } on ImageUsageFailure {
      rethrow;
    } catch (_) {
      throw const ImageUsageFailure('service_unavailable', retryable: true);
    }
  }

  Future<Map<String, dynamic>> gate() async {
    ensureCurrent();
    try {
      final raw = await readGate();
      ensureCurrent();
      return raw == null ? <String, dynamic>{} : usageMap(raw);
    } catch (_) {
      throw const ImageUsageFailure('service_unavailable', retryable: true);
    }
  }

  Future<bool> enrolled() async {
    final value = await gate();
    return value['mode'] == 'enrolled' ||
        value['mode'] == 'enrolling' ||
        value['enrollmentPending'] == true;
  }

  Future<ImageUsage> usage() async => ImageUsage.fromJson(
    await invoke('cloudboardImageUsage', {'action': 'get'}),
  );

  /// Persist the request key before dispatch: an uncertain prepare is retried
  /// with exactly the same payload rather than creating a second reservation.
  Future<void> _prepareQueue = Future<void>.value();
  Future<ClassAdmission> prepare({
    required Map<String, dynamic> workout,
    required List<String> targets,
    required String controllerDeviceId,
    required String clientFingerprint,
  }) async {
    final previous = _prepareQueue;
    final finished = Completer<void>();
    _prepareQueue = finished.future;
    try {
      await previous;
      ensureCurrent();
      return await _prepare(
        workout: workout,
        targets: targets,
        controllerDeviceId: controllerDeviceId,
        clientFingerprint: clientFingerprint,
      );
    } finally {
      finished.complete();
    }
  }

  Future<ClassAdmission> _prepare({
    required Map<String, dynamic> workout,
    required List<String> targets,
    required String controllerDeviceId,
    required String clientFingerprint,
  }) async {
    final prefs = await preferences();
    ensureCurrent();
    final key = 'image-usage.prepare.$actorId';
    final payload = {
      'action': 'prepare',
      'workout': workout,
      'targetDeviceIds': targets,
      'controllerDeviceId': controllerDeviceId,
      'clientFingerprint': clientFingerprint,
    };
    final payloadHash = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    final previous = prefs.getString(key);
    Map<String, dynamic>? pending;
    if (previous != null) {
      pending = usageMap(jsonDecode(previous));
    }
    if (pending != null) {
      var id = pending['admissionId'];
      if (id is! String && pending['payloadHash'] != payloadHash) {
        final original = pending['payload'];
        if (original is! Map) {
          throw const ImageUsageFailure('start_pending', retryable: true);
        }
        final recovered = ClassAdmission.fromJson(
          await invoke('cloudboardClassAdmission', {
            ...usageMap(original),
            'requestId': pending['requestId'],
          }),
        );
        id = recovered.admissionId;
        pending['admissionId'] = id;
        ensureCurrent();
        await _store(prefs, key, jsonEncode(pending));
      }
      if (id is String) {
        final old = await admission(id);
        if (old.status == 'active' || old.pending) return old;
        if (old.status == 'preparing' &&
            pending['payloadHash'] == payloadHash) {
          return old;
        }
        if (old.status == 'preparing') {
          final cancelled = await cancelAdmission(id);
          if (cancelled.status == 'active' || cancelled.pending) {
            return cancelled;
          }
        }
        pending = null;
      }
    }
    final requestId = pending?['requestId'] as String? ?? createEventId();
    await _store(
      prefs,
      key,
      jsonEncode({
        'requestId': requestId,
        'payloadHash': payloadHash,
        'payload': payload,
        if (pending?['admissionId'] != null)
          'admissionId': pending!['admissionId'],
      }),
    );
    final value = ClassAdmission.fromJson(
      await invoke('cloudboardClassAdmission', {
        ...payload,
        'requestId': requestId,
      }),
    );
    ensureCurrent();
    await _store(
      prefs,
      key,
      jsonEncode({
        'requestId': requestId,
        'payloadHash': payloadHash,
        'payload': payload,
        'admissionId': value.admissionId,
      }),
    );
    return value;
  }

  Future<ClassAdmission> admission(String id) async => ClassAdmission.fromJson(
    await invoke('cloudboardClassAdmission', {
      'action': 'get',
      'admissionId': id,
    }),
  );
  Future<ClassAdmission?> pendingAdmission() async {
    final prefs = await preferences();
    ensureCurrent();
    final saved = prefs.getString('image-usage.prepare.$actorId');
    if (saved == null) return null;
    final id = usageMap(jsonDecode(saved))['admissionId'];
    return id is String ? admission(id) : null;
  }

  Future<ClassAdmission> cancelAdmission(String id) async =>
      ClassAdmission.fromJson(
        await invoke('cloudboardClassAdmission', {
          'action': 'cancel',
          'admissionId': id,
          'requestId': createEventId(),
        }),
      );
  Future<ClassAdmission> commit(
    ClassAdmission value,
    Map<String, dynamic> start,
  ) async {
    // Stable per-admission key: both get and a repeated commit converge on the
    // durable server publication; never retry with a replacement session id.
    final result = ClassAdmission.fromJson(
      await invoke('cloudboardClassAdmission', {
        'action': 'commit',
        'requestId': 'commit_${value.admissionId}',
        'admissionId': value.admissionId,
        'sessionId': value.sessionId,
        'manifestHash': value.manifestHash,
        'epoch': value.epoch,
        'start': start,
      }),
    );
    return result;
  }

  Uri _validatedUrl(String value, String endpoint) {
    final uri = Uri.tryParse(value);
    final local =
        uri != null &&
        projectId.startsWith('demo-') &&
        const {'localhost', '127.0.0.1'}.contains(uri.host) &&
        uri.scheme == 'http' &&
        uri.path == '/$projectId/asia-northeast3/$endpoint';
    final remote =
        uri != null &&
        uri.scheme == 'https' &&
        uri.port == 443 &&
        uri.host == 'asia-northeast3-$projectId.cloudfunctions.net' &&
        uri.path == '/$endpoint';
    if (uri == null ||
        (!local && !remote) ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const ImageUsageFailure('media_lease_invalid');
    }
    return uri;
  }

  Future<({Uri uri, String leaseId, ManagedImageAsset asset})> authorizeMedia(
    String source,
  ) async {
    ensureCurrent();
    final uri = _validatedUrl(source, 'cloudboardMedia');
    if (uri.queryParameters.keys.any((key) => key != 'assetId' && key != 'v') ||
        uri.queryParametersAll.values.any((values) => values.length != 1) ||
        !RegExp(r'^\d+$').hasMatch(uri.queryParameters['v'] ?? '')) {
      throw const ImageUsageFailure('media_lease_invalid');
    }
    final assetId = usageString(uri.queryParameters['assetId']);
    final binding = await gate();
    final phase = binding['phase'];
    final inManifest =
        binding['_imageSources'] is! List ||
        (binding['_imageSources'] as List).contains(source);
    final active =
        inManifest &&
        (phase == 'active' ||
            phase == 'committing' ||
            phase == 'grandfathered');
    final preparing = inManifest && phase == 'preparing';
    final lease = await invoke('cloudboardMediaLease', {
      'action': 'issue',
      'requestId': createEventId(),
      'assetIds': [assetId],
      'admissionId': active || preparing ? binding['admissionId'] : null,
      'sessionId': active || preparing ? binding['sessionId'] : null,
      'purpose': active
          ? 'playback'
          : preparing
          ? 'preparation'
          : 'preview',
    });
    final assets = (lease['assets'] as List).map(
      (item) => ManagedImageAsset.fromJson(usageMap(item)),
    );
    if (!assets.any(
      (asset) =>
          asset.assetId == assetId &&
          asset.source == source &&
          asset.generation == uri.queryParameters['v'],
    )) {
      throw const ImageUsageFailure('media_lease_invalid');
    }
    return (
      uri: uri,
      leaseId: usageString(lease['leaseId']),
      asset: assets.singleWhere((asset) => asset.assetId == assetId),
    );
  }

  Future<Uint8List> media(String source) async {
    final authorized = await authorizeMedia(source);
    final authToken = await token();
    ensureCurrent();
    if (authToken.isEmpty) {
      throw const ImageUsageFailure('entitlement_unverified');
    }
    final request = http.Request('GET', authorized.uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $authToken',
        'X-CloudBoard-Media-Lease': authorized.leaseId,
      });
    try {
      final response = await send(request);
      ensureCurrent();
      if (response.statusCode != 200) _httpFailure(response);
      return response.bodyBytes;
    } on ImageUsageFailure {
      rethrow;
    } catch (_) {
      throw const ImageUsageFailure('service_unavailable', retryable: true);
    }
  }

  Never _httpFailure(http.Response response) {
    try {
      throw ImageUsageFailure.fromJson(
        usageMap(jsonDecode(response.body))['error'],
      );
    } on FormatException {
      throw const ImageUsageFailure('service_unavailable', retryable: true);
    }
  }

  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required String purpose,
    String? workoutId,
  }) async {
    ensureCurrent();
    final digest = sha256.convert(bytes).toString();
    final prefs = await preferences();
    ensureCurrent();
    final key =
        'image-usage.upload.$actorId.$purpose.${workoutId ?? ''}.$digest';
    final saved = prefs.getString(key);
    final pending = saved == null ? null : usageMap(jsonDecode(saved));
    var permit = pending?['uploadId'] is String
        ? ImageUploadPermit.fromJson(
            await invoke('cloudboardImageUpload', {
              'action': 'get',
              'uploadId': pending!['uploadId'],
            }),
          )
        : null;
    if (permit?.status == 'stored') return permit!.asset!.source;
    if (permit?.status == 'writing' || permit?.status == 'unknown') {
      throw const ImageUsageFailure(
        'usage_reconciliation_pending',
        retryable: true,
      );
    }
    if (permit != null && permit.status != 'reserved') permit = null;
    final requestId = permit == null && pending?['uploadId'] != null
        ? createEventId()
        : pending?['requestId'] as String? ?? createEventId();
    if (permit == null) {
      await _store(prefs, key, jsonEncode({'requestId': requestId}));
      permit = ImageUploadPermit.fromJson(
        await invoke('cloudboardImageUpload', {
          'action': 'reserve',
          'requestId': requestId,
          'purpose': purpose,
          'workoutId': workoutId,
          'sha256': digest,
          'sizeBytes': bytes.length,
          'contentType': contentType,
        }),
      );
      ensureCurrent();
      await _store(
        prefs,
        key,
        jsonEncode({'requestId': requestId, 'uploadId': permit.uploadId}),
      );
    }
    if (permit.status == 'stored') return permit.asset!.source;
    if (permit.status != 'reserved' || permit.uploadUrl == null) {
      throw const ImageUsageFailure(
        'usage_reconciliation_pending',
        retryable: true,
      );
    }
    final uri = _validatedUrl(permit.uploadUrl!, 'cloudboardImageUploadBody');
    final authToken = await token();
    ensureCurrent();
    if (authToken.isEmpty) {
      throw const ImageUsageFailure('entitlement_unverified');
    }
    try {
      final response = await send(
        http.Request('POST', uri)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $authToken',
            'X-CloudBoard-Upload-Id': permit.uploadId,
            'Content-Type': contentType,
          })
          ..bodyBytes = bytes,
      );
      ensureCurrent();
      if (response.statusCode != 201 && response.statusCode != 200) {
        _httpFailure(response);
      }
      final result = ImageUploadPermit.fromJson(
        usageMap(usageMap(jsonDecode(response.body))['upload']),
      );
      if (result.status != 'stored' || result.asset == null) {
        throw const ImageUsageFailure(
          'usage_reconciliation_pending',
          retryable: true,
        );
      }
      return result.asset!.source;
    } on ImageUsageFailure {
      rethrow;
    } catch (_) {
      // A lost HTTP result is not proof of a failed write. Keep the permit
      // and selected bytes; requery that same id on the next explicit retry.
      throw const ImageUsageFailure(
        'usage_reconciliation_pending',
        retryable: true,
      );
    }
  }
}

/// Existing storage datasources call this before touching the SDK. A missing
/// enrollment fence retains the installed-client path; a failed fence read or
/// enrolled service failure never falls through to a direct upload.
Future<String?> managedUploadIfEnrolled(
  FirebaseApp app, {
  required String ownerId,
  required Uint8List bytes,
  required String contentType,
  required String purpose,
  String? workoutId,
}) async {
  final client = ImageUsageDataSource.forApp(app);
  try {
    if (client.actorId != ownerId) {
      throw const ImageUsageFailure('entitlement_unverified');
    }
    if (!await client.enrolled()) return null;
    return await client.upload(
      bytes: bytes,
      contentType: contentType,
      purpose: purpose,
      workoutId: workoutId,
    );
  } finally {
    client.dispose();
  }
}
