import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

int preparationServerNow(int serverOffsetMs, {int? localNowMs}) =>
    (localNowMs ?? DateTime.now().millisecondsSinceEpoch) + serverOffsetMs;

/// Separate from playback/display ACK. A candidate never changes an active class.
class DisplayPreparation {
  const DisplayPreparation({
    required this.sessionId,
    required this.revision,
    required this.manifestHash,
    required this.workoutId,
    required this.expiresAtMs,
    required this.targetDeviceIds,
    required this.images,
    required this.sounds,
    required this.requiredProtocol,
  });
  final String sessionId, manifestHash, workoutId;
  final int revision, expiresAtMs, requiredProtocol;
  final List<String> targetDeviceIds, images, sounds;
  bool expired(int nowMs) => nowMs >= expiresAtMs;
}

String preparationFingerprint(Workout workout, Iterable<String> targetIds) {
  final sorted = targetIds.toSet().toList()..sort();
  // Includes effective preferences and every immutable workout field. This is
  // a short-lived candidate identity, never a persisted workout serialization.
  return sha256
      .convert(utf8.encode('${workout.toString()}\n${jsonEncode(sorted)}'))
      .toString();
}

DisplayPreparation prepareDisplayCandidate(
  Workout workout,
  Iterable<String> targets, {
  required String sessionId,
  required int revision,
  required int nowMs,
}) {
  final targetIds = targets.toSet().toList()..sort();
  final images = <String>{
    if (workout.countdownImageSource.isNotEmpty) workout.countdownImageSource,
    for (final module in workout.modules)
      if (!hasSlideDesign(module) && module.imageSource.isNotEmpty)
        module.imageSource,
  }.toList();
  final sounds = workout.soundVolume <= 0
      ? <String>[]
      : <String>{
          workout.countdownSound.name,
          workout.workStartSound.name,
          workout.restStartSound.name,
          workout.workoutEndSound.name,
        }.where((s) => s != 'silent').toList();
  if (images.length > 64 ||
      targetIds.length > 32 ||
      utf8.encode(jsonEncode(images)).length > 10000000) {
    throw StateError('수업 자료가 준비 확인 범위를 초과했어요. 슬라이드 이미지를 줄인 뒤 다시 확인해 주세요.');
  }
  return DisplayPreparation(
    sessionId: sessionId,
    revision: revision,
    manifestHash: preparationFingerprint(workout, targetIds),
    workoutId: workout.id,
    expiresAtMs: nowMs + 90000,
    targetDeviceIds: targetIds,
    images: images,
    sounds: sounds,
    requiredProtocol: requiredTimingProtocol(workout),
  );
}

class DisplayPreparationReceipt {
  const DisplayPreparationReceipt({
    required this.sessionId,
    required this.revision,
    required this.manifestHash,
    required this.status,
    required this.checkedAtMs,
    required this.imageCount,
    required this.audioReady,
  });
  final String sessionId, manifestHash, status;
  final int revision, checkedAtMs, imageCount;
  final bool audioReady;
  bool readyFor(DisplayPreparation request, int nowMs) =>
      !request.expired(nowMs) &&
      sessionId == request.sessionId &&
      revision == request.revision &&
      manifestHash == request.manifestHash &&
      checkedAtMs >= request.expiresAtMs - 90000 &&
      checkedAtMs <= nowMs + 5000 &&
      status == 'ready' &&
      imageCount == request.images.length &&
      audioReady;
}

class DisplayPreparationProof {
  const DisplayPreparationProof({
    required this.manifestHash,
    this.sessionId,
    this.revision,
    this.legacyDeviceIds = const [],
  });
  final String manifestHash;
  final String? sessionId;
  final int? revision;
  final List<String> legacyDeviceIds;
}

enum DisplayPreparationStatus {
  offline,
  updateRequired,
  legacy,
  waiting,
  failed,
  ready,
  expired,
}

DisplayPreparationStatus displayPreparationStatus(
  DisplayDevice device,
  int requiredProtocol,
  DisplayPreparation? request,
  DisplayPreparationReceipt? receipt,
  int nowMs,
) {
  if (!device.recentlySeen(nowMs)) return DisplayPreparationStatus.offline;
  if (device.playbackProtocol < requiredProtocol) {
    return DisplayPreparationStatus.updateRequired;
  }
  if (device.preparationProtocol < 1) return DisplayPreparationStatus.legacy;
  final health = device.preparationHealth;
  if (health.code.isNotEmpty &&
      (health.requestId == null || health.requestId == request?.sessionId)) {
    return DisplayPreparationStatus.failed;
  }
  if (request == null) return DisplayPreparationStatus.waiting;
  if (request.expired(nowMs)) return DisplayPreparationStatus.expired;
  if (receipt?.readyFor(request, nowMs) == true) {
    return DisplayPreparationStatus.ready;
  }
  if (receipt?.sessionId == request.sessionId &&
      receipt?.revision == request.revision &&
      receipt?.manifestHash == request.manifestHash &&
      receipt?.status == 'failed') {
    return DisplayPreparationStatus.failed;
  }
  return DisplayPreparationStatus.waiting;
}
