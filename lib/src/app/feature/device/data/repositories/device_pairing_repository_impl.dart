import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';

part 'device_pairing_repository_impl.g.dart';

class DevicePairingRepositoryImpl implements DevicePairingRepository {
  const DevicePairingRepositoryImpl(this._dataSource);

  final DevicePairingRealtimeDataSource _dataSource;

  @override
  Future<DevicePairing> issue({required String deviceId}) =>
      _dataSource.issue(deviceId: deviceId);

  @override
  Stream<List<DisplayDevice>> watchDevices() => _dataSource.watchDevices();

  @override
  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  }) => _dataSource.claim(code: code, name: name, zoneName: zoneName);

  @override
  Future<void> unpair(String deviceId) => _dataSource.unpair(deviceId);

  @override
  Future<void> setDisplayState({
    required String deviceId,
    required String displayState,
  }) => _dataSource.setDisplayState(
    deviceId: deviceId,
    displayState: displayState,
  );

  @override
  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) => _dataSource.acknowledge(
    deviceId: deviceId,
    sessionId: sessionId,
    revision: revision,
  );
}

@Riverpod(keepAlive: true)
DevicePairingRepository devicePairingRepository(Ref ref) {
  final auth = FirebaseAuth.instance;
  final ownerId = ref.watch(accountOwnerIdProvider).value;
  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: realtimeDatabaseUrl,
  );
  return DevicePairingRepositoryImpl(
    DevicePairingRealtimeDataSource(database, auth, ownerId),
  );
}
