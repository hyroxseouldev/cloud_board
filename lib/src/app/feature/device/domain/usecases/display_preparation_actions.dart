import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
part 'display_preparation_actions.g.dart';

class DisplayPreparationActions {
  const DisplayPreparationActions(
    this.repository,
    this.devices, {
    this.serverNow,
  });
  final Future<int> Function()? serverNow;
  final DisplayPreparationRepository repository;
  final DevicePairingRepository devices;
  Future<void> verifyStart(
    Workout workout,
    List<String> targets,
    DisplayPreparationProof? proof, {
    int? nowMs,
  }) async {
    final all = await devices.watchDevices().first.timeout(
      const Duration(seconds: 5),
    );
    final selected = targets.isEmpty
        ? all
        : all.where((d) => targets.contains(d.id)).toList();
    if (targets.any((id) => !selected.any((d) => d.id == id))) {
      throw StateError('디스플레이 연결이 변경됐어요. 수업 준비를 다시 확인해 주세요.');
    }
    final required = requiredTimingProtocol(workout);
    if (selected.any((d) => d.playbackProtocol < required)) {
      throw StateError('이 수업은 TV 앱 업데이트가 필요해요.');
    }
    // Legacy compatible direct starts remain available. New clients advertise
    // preparation explicitly and cannot bypass its media readiness check.
    final modern = selected.where((d) => d.preparationProtocol >= 1).toList();
    if (modern.isEmpty && proof == null) return;
    if (proof == null ||
        proof.manifestHash != preparationFingerprint(workout, targets)) {
      throw StateError('수업 내용이나 설정이 바뀌었어요. 수업 준비를 다시 확인해 주세요.');
    }
    // Resolve optional modern evidence before reading the server clock, so
    // both manual legacy confirmations and media receipts use the same final
    // freshness check immediately before starting.
    final request = modern.isEmpty ? null : await repository.current();
    final receipts = modern.isEmpty
        ? const <String, DisplayPreparationReceipt>{}
        : await repository.receipts();
    final now =
        nowMs ??
        await serverNow?.call() ??
        DateTime.now().millisecondsSinceEpoch;
    for (final old in selected.where((d) => d.preparationProtocol < 1)) {
      if (!proof.legacyDeviceIds.contains(old.id) || !old.recentlySeen(now)) {
        throw StateError('구형 TV의 화면을 직접 확인하거나 재생 대상에서 제외해 주세요.');
      }
    }
    if (modern.isEmpty) return;
    if (request == null ||
        request.sessionId != proof.sessionId ||
        request.revision != proof.revision ||
        request.manifestHash != proof.manifestHash ||
        request.targetDeviceIds
            .toSet()
            .difference(targets.toSet())
            .isNotEmpty ||
        targets
            .toSet()
            .difference(request.targetDeviceIds.toSet())
            .isNotEmpty) {
      throw StateError('수업 준비 요청이 바뀌었어요. 다시 확인해 주세요.');
    }
    if (modern.any(
      (d) =>
          displayPreparationStatus(d, required, request, receipts[d.id], now) !=
          DisplayPreparationStatus.ready,
    )) {
      throw StateError('아직 준비되지 않은 TV가 있어요. 재시도하거나 대상에서 제외해 주세요.');
    }
  }
}

@riverpod
DisplayPreparationActions displayPreparationActions(Ref ref) {
  final playback = ref.watch(playbackRepositoryProvider);
  return DisplayPreparationActions(
    ref.watch(displayPreparationRepositoryProvider),
    ref.watch(devicePairingRepositoryProvider),
    serverNow: () async => preparationServerNow(
      await playback.watchServerTimeOffset().first.timeout(
        const Duration(seconds: 5),
      ),
    ),
  );
}
