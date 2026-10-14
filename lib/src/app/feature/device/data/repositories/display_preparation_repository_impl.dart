import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/display_preparation_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
part 'display_preparation_repository_impl.g.dart';

class DisplayPreparationRepositoryImpl implements DisplayPreparationRepository {
  const DisplayPreparationRepositoryImpl(this.source);
  final DisplayPreparationDataSource source;
  @override
  Future<void> request(DisplayPreparation request) => source.request(request);
  @override
  Future<void> cancel(String sessionId) => source.cancel(sessionId);
  @override
  Stream<DisplayPreparation?> watchRequest(String deviceId) =>
      source.watchRequest();
  @override
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() =>
      source.watchReceipts();
  @override
  Future<DisplayPreparation?> current() => source.current();
  @override
  Future<Map<String, DisplayPreparationReceipt>> receipts() =>
      source.receipts();
  @override
  Future<void> respond(
    String deviceId,
    DisplayPreparation request, {
    required bool ready,
    required int imageCount,
    required bool audioReady,
  }) => source.respond(
    deviceId,
    request,
    ready: ready,
    imageCount: imageCount,
    audioReady: audioReady,
  );
  @override
  Future<void> heartbeat(String deviceId, {bool ready = false}) =>
      source.heartbeat(deviceId, ready: ready);
  @override
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
  }) => source.reportHealth(
    deviceId,
    stage: stage,
    code: code,
    attempt: attempt,
    requestId: requestId,
  );
}

@riverpod
DisplayPreparationRepository displayPreparationRepository(Ref ref) {
  final auth = FirebaseAuth.instance;
  final scope = ref.watch(accountOwnerIdProvider);
  final owner = scope.isLoading || scope.hasError ? null : scope.value;
  if (owner == null) throw StateError('연결된 센터를 확인해 주세요.');
  return DisplayPreparationRepositoryImpl(
    DisplayPreparationDataSource(
      FirebaseDatabase.instanceFor(
        app: auth.app,
        databaseURL: cloudBoardRealtimeDatabaseUrl,
      ),
      owner,
    ),
  );
}
