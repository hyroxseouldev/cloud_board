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
    final cohort = proof?.preparedTargetDeviceIds;
    if (cohort != null &&
        (cohort.isEmpty ||
            targets.isEmpty ||
            cohort.toSet().length != cohort.length ||
            targets.toSet().length != targets.length ||
            !cohort.toSet().containsAll(targets))) {
      throw StateError('수업 준비 대상이 바뀌었어요. 다시 확인해 주세요.');
    }
    final all = await devices.watchDevices().first.timeout(
      const Duration(seconds: 5),
    );
    final selected = targets.isEmpty
        ? all
        : all.where((d) => targets.contains(d.id)).toList();
    if (targets.any((id) => !selected.any((d) => d.id == id)) ||
        selected.any(
          (device) =>
              !device.paired ||
              (cohort != null && device.displayState != 'auto'),
        )) {
      throw StateError('디스플레이 연결이 변경됐어요. 수업 준비를 다시 확인해 주세요.');
    }
    final required = requiredTimingProtocol(workout);
    if (selected.any((d) => d.playbackProtocol < required)) {
      throw StateError('이 수업은 TV 앱 업데이트가 필요해요.');
    }
    if (selected.isEmpty) return;
    // Older displays use connection/timing compatibility; modern displays still
    // need the exact candidate and media receipt. No manual checkbox is evidence.
    final modern = selected.where((d) => d.preparationProtocol >= 1).toList();
    if ((modern.isNotEmpty && proof == null) ||
        (proof != null &&
            (proof.clientFingerprint ?? proof.manifestHash) !=
                preparationFingerprint(workout, cohort ?? targets))) {
      throw StateError('수업 내용이나 설정이 바뀌었어요. 수업 준비를 다시 확인해 주세요.');
    }
    // Resolve optional modern evidence before reading the server clock, so
    // both legacy connections and media receipts use the same final
    // freshness check immediately before starting.
    // Install both error handlers immediately and preserve the original error.
    final evidence = modern.isEmpty && cohort == null
        ? null
        : await Future.wait<Object?>([
            repository.current(),
            repository.receipts(),
          ]);
    final request = evidence?[0] as DisplayPreparation?;
    final receipts = evidence == null
        ? const <String, DisplayPreparationReceipt>{}
        : evidence[1] as Map<String, DisplayPreparationReceipt>;
    final now =
        nowMs ??
        await serverNow?.call() ??
        DateTime.now().millisecondsSinceEpoch;
    for (final old in selected.where((d) => d.preparationProtocol < 1)) {
      if (!old.recentlySeen(now)) {
        throw StateError('최근 응답이 없는 TV가 있어요. 연결을 확인하거나 재생 대상에서 제외해 주세요.');
      }
    }
    if (modern.isEmpty && cohort == null) return;
    if (proof == null ||
        request == null ||
        request.workoutId != workout.id ||
        request.expired(now) ||
        request.sessionId != proof.sessionId ||
        request.revision != proof.revision ||
        request.manifestHash != proof.manifestHash ||
        request.targetDeviceIds
            .toSet()
            .difference((cohort ?? targets).toSet())
            .isNotEmpty ||
        (cohort ?? targets)
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
