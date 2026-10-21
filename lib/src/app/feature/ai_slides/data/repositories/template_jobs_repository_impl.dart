import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/template_jobs_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/template_jobs_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/template_job_model.dart';

part 'template_jobs_repository_impl.g.dart';

@riverpod
TemplateJobsRepository? templateJobsRepository(Ref ref) {
  final scope = ref.watch(centerSlideCatalogScopeProvider);
  final owner = ref.watch(aiSlidesOwnerIdProvider);
  if (scope == null || owner == null || scope.ownerId != owner) return null;
  final auth = ref.watch(firebaseClientAuthProvider);
  var active = true;
  final repository = TemplateJobsRepositoryImpl(
    source: FirebaseTemplateJobsDataSource(
      functions: FirebaseFunctions.instanceFor(
        app: auth.app,
        region: 'asia-northeast3',
      ),
      firestore: FirebaseFirestore.instanceFor(app: auth.app),
      ownerId: owner,
      centerId: scope.centerId,
    ),
    preferences: SharedPreferences.getInstance,
    scopeKey:
        '${auth.app.options.projectId}/${auth.app.name}/$owner/${scope.centerId}',
    isCurrent: () =>
        active &&
        ref.mounted &&
        auth.currentUser?.uid == owner &&
        ref.read(aiSlidesOwnerIdProvider) == owner &&
        ref.read(centerSlideCatalogScopeProvider) == scope,
  );
  ref.onDispose(() {
    active = false;
    repository.clear();
  });
  return repository;
}

class TemplateJobsRepositoryImpl implements TemplateJobsRepository {
  TemplateJobsRepositoryImpl({
    required this.source,
    required this.preferences,
    required String scopeKey,
    required this.isCurrent,
  }) : outboxKey =
           'template-job-outbox-v1-${sha256.convert(utf8.encode(scopeKey))}';
  final TemplateJobsDataSource source;
  final Future<SharedPreferences> Function() preferences;
  final bool Function() isCurrent;
  final String outboxKey;
  Future<TemplateJobsReply>? _sending;
  String? _assetKey;
  Uint8List? _asset;
  DateTime? _assetAt;
  Future<Uint8List>? _loadingAsset;
  void clear() {
    _asset = null;
    _assetKey = null;
    _loadingAsset = null;
  }

  void _guard() {
    if (!isCurrent()) {
      clear();
      throw const AiSlidesFailure(
        '계정 또는 센터가 변경되었어요.',
        code: 'permission-denied',
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> input,
  ) async {
    _guard();
    final value = await source.call(action, input);
    _guard();
    return value;
  }

  @override
  Stream<List<TemplateJob>> watch() => source.watch().map((rows) {
    _guard();
    return rows.map(readTemplateJob).toList();
  });
  @override
  Future<TemplateJobsReply> list({String? before}) async =>
      readTemplateJobsReply(await _call('list', {'before': ?before}));

  Future<Map<String, dynamic>?> _pending() async {
    _guard();
    final prefs = await preferences();
    await prefs.reload();
    _guard();
    final raw = prefs.getString(outboxKey);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<bool> hasUnresolved() async => await _pending() != null;

  @override
  Future<TemplateJobsReply> enqueue(StudioInput input, String requestId) =>
      _submit(templateJobInput(input, requestId));
  @override
  Future<TemplateJobsReply> retry(TemplateJob job, String requestId) {
    if (job.status != 'failed' || !job.retryable) {
      throw const AiSlidesFailure('이 요청은 재생성할 수 없어요. 접수 상태를 먼저 확인해 주세요.');
    }
    return _submit({'requestId': requestId, 'retryOf': job.requestId});
  }

  Future<TemplateJobsReply> _submit(Map<String, dynamic> input) {
    if (_sending != null) return _sending!;
    final future = _persistAndSend(input);
    _sending = future;
    return future.whenComplete(() => _sending = null);
  }

  Future<TemplateJobsReply> _persistAndSend(Map<String, dynamic> input) async {
    if (await _pending() != null) {
      throw const AiSlidesFailure(
        '이전 접수 여부를 먼저 확인해 주세요.',
        code: 'pending-request',
      );
    }
    final prefs = await preferences();
    _guard();
    if (!await prefs.setString(outboxKey, jsonEncode(input))) {
      throw const AiSlidesFailure('접수 정보를 기기에 보관하지 못했어요. 다시 시도해 주세요.');
    }
    return _send(input);
  }

  Future<TemplateJobsReply> _send(Map<String, dynamic> input) async {
    try {
      final value = readTemplateJobsReply(await _call('enqueue', input));
      if (value.jobs.single.requestId != input['requestId']) {
        throw const FormatException('접수 ID가 일치하지 않아요.');
      }
      await _acknowledge(input['requestId'] as String);
      return value;
    } on AiSlidesFailure catch (error) {
      // Transport/timeout/unknown responses retain the *same* durable request.
      if ([
        'invalid-argument',
        'failed-precondition',
        'resource-exhausted',
        'permission-denied',
        'unauthenticated',
        'not-found',
      ].contains(error.code)) {
        await _acknowledge(input['requestId'] as String);
      }
      rethrow;
    }
  }

  Future<void> _acknowledge(String id) async {
    final prefs = await preferences();
    // May clear only this account/center's own receipt, including logout races.
    final raw = prefs.getString(outboxKey);
    if (raw != null && (jsonDecode(raw) as Map)['requestId'] == id) {
      if (!await prefs.remove(outboxKey)) {
        throw const AiSlidesFailure(
          '접수 확인을 기기에 반영하지 못했어요. 같은 요청으로 다시 확인해 주세요.',
        );
      }
    }
  }

  @override
  Future<TemplateJobsReply?> recover() async {
    final input = await _pending();
    if (input == null) return null;
    try {
      final value = readTemplateJobsReply(
        await _call('status', {'requestId': input['requestId']}),
      );
      if (value.jobs.single.requestId != input['requestId']) {
        throw const FormatException('접수 ID가 일치하지 않아요.');
      }
      await _acknowledge(input['requestId'] as String);
      return value;
    } on AiSlidesFailure catch (error) {
      if (error.code != 'not-found') rethrow;
      // Explicit recovery uses the exact persisted payload and idempotency key.
      return _send(input);
    }
  }

  @override
  Future<Uint8List> asset(TemplateJob job) async {
    _guard();
    final current = readTemplateJobsReply(
      await _call('status', {'requestId': job.requestId}),
    ).jobs.single;
    if (!current.complete ||
        current.requestId != job.requestId ||
        current.sha256 != job.sha256) {
      clear();
      throw const AiSlidesFailure('완성 이미지 정보를 다시 확인해 주세요.');
    }
    final key = '${job.requestId}/${job.sha256}';
    if (_assetKey == key &&
        _asset != null &&
        DateTime.now().difference(_assetAt!) < const Duration(minutes: 5)) {
      return Uint8List.fromList(_asset!);
    }
    // One image request at a time, one bounded in-memory image; no disk/public URL.
    final pending = _loadingAsset;
    if (pending != null) {
      await pending;
      return asset(job);
    }
    final request = () async {
      final bytes = readTemplateJobPng(
        await _call('asset', {'requestId': job.requestId}),
        job,
      );
      _guard();
      _assetKey = key;
      _asset = bytes;
      _assetAt = DateTime.now();
      return Uint8List.fromList(bytes);
    }();
    _loadingAsset = request;
    try {
      return await request;
    } finally {
      _loadingAsset = null;
    }
  }
}
