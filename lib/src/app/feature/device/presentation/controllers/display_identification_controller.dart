import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';

part 'display_identification_controller.g.dart';

typedef DisplayIdentification = ({String nonce, int expiresAtMs});

@riverpod
class DisplayIdentificationController
    extends _$DisplayIdentificationController {
  @override
  AsyncValue<DisplayIdentification?> build(String deviceId) =>
      const AsyncData(null);

  Future<void> identify() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<DisplayIdentification?>(() async {
      final offset = ref.read(serverTimeOffsetProvider).value ?? 0;
      final nonce =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      final expires = DateTime.now().millisecondsSinceEpoch + offset + 30000;
      await ref
          .read(devicePairingActionsProvider)
          .identify(deviceId, nonce, expires)
          .timeout(const Duration(seconds: 10));
      return (nonce: nonce, expiresAtMs: expires);
    });
    if (ref.mounted) state = result;
  }
}
