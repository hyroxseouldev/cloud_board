import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_raster_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/ai_raster_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
part 'ai_raster_repository_impl.g.dart';

@riverpod
AiRasterRepository? aiRasterRepository(Ref ref) {
  final scope = ref.watch(centerSlideCatalogScopeProvider);
  final auth = ref.watch(firebaseClientAuthProvider);
  if (scope == null) return null;
  var active = true;
  final repository = AiRasterRepositoryImpl(
    AiRasterDataSource(
      FirebaseFunctions.instanceFor(app: auth.app, region: 'asia-northeast3'),
      scope.centerId,
      () =>
          active &&
          ref.mounted &&
          ref.read(centerSlideCatalogScopeProvider) == scope &&
          auth.currentUser?.uid == scope.ownerId,
    ),
  );
  ref.onDispose(() {
    active = false;
    repository.dispose();
  });
  return repository;
}

class AiRasterRepositoryImpl implements AiRasterRepository {
  AiRasterRepositoryImpl(this.source, {this.compose = composeRasterSlide});
  final AiRasterDataSource source;
  final Future<Uint8List> Function(
    AiRasterDraft,
    AiRasterBrand,
    Uint8List,
    Uint8List,
  )
  compose;
  final _cache = <String, ({Uint8List bytes, DateTime expires})>{};
  final _pending = <String, Future<Uint8List>>{};
  final _slots = <Completer<void>>[];
  int _active = 0;
  bool _disposed = false;
  String? _finalKey;
  Future<Uint8List>? _finalPng;
  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  AiRasterReply _reply(Map<String, dynamic> json) => (
    job: AiRasterJob.fromJson(_map(json['job'])),
    remaining: json['remaining'] as int,
    limit: json['limit'] as int,
  );
  @override
  Future<AiRasterContext> context() async {
    final json = await source.call('context');
    return (
      brand: AiRasterBrand.fromJson(_map(json['brand'])),
      recent: json['recent'] == null
          ? null
          : AiRasterJob.fromJson(_map(json['recent'])),
      previous: json['previous'] == null
          ? null
          : AiRasterJob.fromJson(_map(json['previous'])),
      allowed: json['allowed'] == true,
      enabled: json['enabled'] == true,
      remaining: json['remaining'] as int,
      limit: json['limit'] as int,
    );
  }

  @override
  Future<AiRasterGroups> organize(AiRasterDraft draft) async {
    final json = await source.call('organize', {
      'rawWod': draft.rawWod,
      'brief': draft.brief,
    });
    return (
      groups: (json['groups'] as List)
          .map((value) => AiRasterGroup.fromJson(_map(value)))
          .toList(),
      remaining: json['remaining'] as int,
      limit: json['limit'] as int,
    );
  }

  @override
  Future<AiRasterReply> generate(
    AiRasterDraft draft,
    AiRasterBrand brand,
    String requestId,
    String? previousRequestId,
  ) async => _reply(
    await source.call('generate', {
      'requestId': requestId,
      'brandKey': brand.key,
      'draft': draft.toJson(),
      'previousRequestId': previousRequestId,
    }),
  );
  @override
  Future<AiRasterReply> status(String requestId) async =>
      _reply(await source.call('status', {'requestId': requestId}));
  @override
  Future<AiRasterJob> confirm(AiRasterJob job, AiRasterBrand brand) async {
    final json = await source.call('confirm', {'requestId': job.requestId});
    final confirmed = AiRasterJob.fromJson(_map(json['job']));
    if (AiRasterBrand.fromJson(_map(json['brand'])) != brand ||
        confirmed != job) {
      throw const AiSlidesFailure('확인한 시안이 변경되었어요. 다시 확인해 주세요.');
    }
    return confirmed;
  }

  @override
  Future<Uint8List> asset(
    AiRasterBrand brand,
    AiRasterJob? job,
    String kind,
  ) async {
    if (_disposed || !source.isCurrent()) {
      throw const AiSlidesFailure('센터 연결이 변경되었어요.');
    }
    final expected = kind == 'logo'
        ? brand.logo
        : kind == 'reference'
        ? brand.reference
        : job!.artifact!;
    final key = '${brand.key}/${job?.requestId}/$kind/${expected.sha256}';
    final cached = _cache.remove(key);
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      _cache[key] = cached;
      return Uint8List.fromList(cached.bytes);
    }
    final future = _pending[key] ??= _readAsset(
      brand,
      job,
      kind,
      expected,
      key,
    );
    try {
      final bytes = await future;
      if (_disposed || !source.isCurrent()) {
        throw const AiSlidesFailure('센터 연결이 변경되었어요.');
      }
      return Uint8List.fromList(bytes);
    } finally {
      if (identical(_pending[key], future)) _pending.remove(key);
    }
  }

  Future<Uint8List> _readAsset(
    AiRasterBrand brand,
    AiRasterJob? job,
    String kind,
    AiRasterAsset expected,
    String key,
  ) async {
    if (_active >= 3) {
      final slot = Completer<void>();
      _slots.add(slot);
      await slot.future;
    } else {
      _active++;
    }
    try {
      if (_disposed || !source.isCurrent()) {
        throw const AiSlidesFailure('센터 연결이 변경되었어요.');
      }
      final json = await source.call('asset', {
        'kind': kind,
        if (job != null) 'requestId': job.requestId,
      });
      final encoded = json['base64'] as String;
      if (_disposed ||
          json['brandKey'] != brand.key ||
          encoded.length > 5592408) {
        throw const AiSlidesFailure('센터 이미지 권한 또는 버전을 확인해 주세요.');
      }
      final bytes = base64Decode(encoded);
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < 33 ||
          bytes.length > 4 * 1024 * 1024 ||
          signature.indexed.any((v) => bytes[v.$1] != v.$2) ||
          sha256.convert(bytes).toString() != expected.sha256 ||
          ByteData.sublistView(bytes).getUint32(16) != expected.width ||
          ByteData.sublistView(bytes).getUint32(20) != expected.height) {
        throw const AiSlidesFailure('이미지 버전 또는 크기가 변경되었어요.');
      }
      final now = DateTime.now();
      _cache.removeWhere((_, value) => value.expires.isBefore(now));
      while (_cache.isNotEmpty &&
          _cache.values.fold<int>(
                bytes.length,
                (total, value) => total + value.bytes.length,
              ) >
              20 * 1024 * 1024) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = (
        bytes: Uint8List.fromList(bytes),
        expires: now.add(const Duration(minutes: 2)),
      );
      return bytes;
    } finally {
      if (_slots.isNotEmpty) {
        _slots.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  @override
  Future<WorkoutModule> createModule(
    AiRasterJob job,
    AiRasterBrand brand,
  ) async {
    await confirm(job, brand);
    final key = '${brand.key}/${job.requestId}/${job.artifact?.sha256}';
    if (_finalKey != key || _finalPng == null) {
      _finalKey = key;
      _finalPng = () async {
        final images = await Future.wait([
          asset(brand, job, 'artwork'),
          asset(brand, null, 'logo'),
        ]);
        return compose(job.draft, brand, images[0], images[1]);
      }();
    }
    Uint8List png;
    try {
      png = await _finalPng!;
    } catch (_) {
      if (_finalKey == key) {
        _finalPng = null;
      }
      rethrow;
    }
    await confirm(
      job,
      brand,
    ); // Fresh authority/version after encoding, before insertion.
    if (_disposed) throw const AiSlidesFailure('센터 연결이 변경되었어요.');
    final module = WorkoutModule.empty('ai-raster-${job.requestId}');
    return module.copyWith(
      name: job.draft.title,
      text: job.draft.rawWod,
      imageSource: 'data:image/png;base64,${base64Encode(png)}',
      showTimer: false,
      showSets: false,
      appearance: module.appearance.copyWith(
        showTitle: false,
        showBody: false,
        showBrand: false,
        timerX: .84,
        timerY: .5,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    _pending.clear();
    _finalPng = null;
  }
}
