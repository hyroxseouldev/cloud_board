import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_brand_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_local_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/repositories/store_operations_repository.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';

part 'store_operations_repository_impl.g.dart';

class StoreOperationsRepositoryImpl implements StoreOperationsRepository {
  const StoreOperationsRepositoryImpl(
    this._realtime,
    this._storage,
    this._local,
  );

  final StoreOperationsRealtimeDataSource _realtime;
  final StoreBrandStorageDataSource _storage;
  final StoreOperationsLocalDataSource _local;

  @override
  Stream<BrandTemplate> watchBrandTemplate() async* {
    final cached = await _local.loadBrandTemplate();
    if (cached != null) yield cached.toEntity();
    await for (final model in _realtime.watchBrandTemplate()) {
      await _local.saveBrandTemplate(model);
      yield model.toEntity();
    }
  }

  @override
  Stream<List<WorkoutSchedule>> watchSchedules() async* {
    final cached = await _local.loadSchedules();
    if (cached.isNotEmpty) {
      yield cached.map((item) => item.toEntity()).toList();
    }
    await for (final items in _realtime.watchSchedules()) {
      await _local.saveSchedules(items);
      yield items.map((item) => item.toEntity()).toList();
    }
  }

  @override
  Stream<List<OperationEvent>> watchEvents() => _realtime.watchEvents().map(
    (items) => items.map((item) => item.toEntity()).toList(),
  );

  @override
  Future<void> saveBrandTemplate(BrandTemplate template) async {
    final urls = <String>[];
    for (final source in template.promotionImageUrls) {
      if (source.startsWith('https://') || source.startsWith('http://')) {
        urls.add(source);
      } else {
        final image = WorkoutImageSource.decode(source);
        if (!WorkoutImageSource.supportedContentTypes.contains(
          image.contentType,
        )) {
          throw const FormatException('지원하지 않는 이미지 형식입니다.');
        }
        urls.add(
          await _storage.upload(
            bytes: image.bytes,
            extension: image.contentType.split('/').last,
            purpose: 'promotion',
          ),
        );
      }
    }
    final model = BrandTemplateModel.fromEntity(
      template.copyWith(promotionImageUrls: urls),
    );
    await _realtime.saveBrandTemplate(model);
    await _local.saveBrandTemplate(model);
  }

  @override
  Future<String> uploadBrandImage({
    required Uint8List bytes,
    required String extension,
    required String purpose,
  }) => _storage.upload(bytes: bytes, extension: extension, purpose: purpose);

  @override
  Future<void> saveSchedule(WorkoutSchedule schedule) =>
      _realtime.saveSchedule(WorkoutScheduleModel.fromEntity(schedule));

  @override
  Future<void> deleteSchedule(String scheduleId) =>
      _realtime.deleteSchedule(scheduleId);

  @override
  Future<bool> claimOccurrence(String scheduleId, String occurrenceKey) =>
      _realtime.claimOccurrence(scheduleId, occurrenceKey);

  @override
  Future<void> recordEvent({
    required String type,
    String? deviceId,
    String? workoutId,
    String? workoutName,
    bool scheduled = false,
    int? scheduledAtMs,
  }) => _realtime.recordEvent(
    type: type,
    deviceId: deviceId,
    workoutId: workoutId,
    workoutName: workoutName,
    scheduled: scheduled,
    scheduledAtMs: scheduledAtMs,
  );
}

@Riverpod(keepAlive: true)
StoreOperationsRepository storeOperationsRepository(Ref ref) {
  final auth = FirebaseAuth.instance;
  final ownerId = ref.watch(accountOwnerIdProvider).value;
  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: realtimeDatabaseUrl,
  );
  return StoreOperationsRepositoryImpl(
    StoreOperationsRealtimeDataSource(database, ownerId),
    StoreBrandStorageDataSource(FirebaseStorage.instance, auth),
    StoreOperationsLocalDataSource(SharedPreferencesAsync()),
  );
}
