import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_identification_controller.dart';

/// This is deliberately separate from claim success: a new/old TV must draw
/// the silent card and echo this attempt's nonce before the user can confirm it.
class DisplayVerification extends HookConsumerWidget {
  const DisplayVerification({
    super.key,
    this.deviceId,
    this.pairingCode,
    required this.onDone,
  });
  final String? deviceId, pairingCode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    final device = devices.value
        ?.where(
          (d) => deviceId != null
              ? d.id == deviceId
              : d.pairingCode == pairingCode,
        )
        .firstOrNull;
    if (device != null) {
      return _CheckDevice(deviceId: device.id, onDone: onDone);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('등록 요청이 접수되었습니다. TV 연결 확인은 아직 끝나지 않았어요.'),
        const SizedBox(height: 12),
        const Text('TV 앱을 켜 둔 채 인터넷 연결을 확인하세요. 목록이 나타나지 않으면 다시 불러와 주세요.'),
        TextButton(
          onPressed: () => ref.invalidate(displayDevicesProvider),
          child: const Text('등록 목록 다시 확인'),
        ),
      ],
    );
  }
}

class _CheckDevice extends HookConsumerWidget {
  const _CheckDevice({required this.deviceId, required this.onDone});
  final String deviceId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = displayIdentificationControllerProvider(deviceId);
    final state = ref.watch(provider);
    final device = ref
        .watch(displayDevicesProvider)
        .value
        ?.where((d) => d.id == deviceId)
        .firstOrNull;
    final now = useState(DateTime.now().millisecondsSinceEpoch);
    final saving = useState(false);
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now().millisecondsSinceEpoch,
      );
      Future.microtask(() {
        if (context.mounted) ref.read(provider.notifier).identify();
      });
      return timer.cancel;
    }, [deviceId]);
    final request = state.value;
    final expired =
        request != null &&
        DateTime.now().millisecondsSinceEpoch +
                (ref.watch(serverTimeOffsetProvider).value ?? 0) >=
            request.expiresAtMs;
    final confirmed =
        request != null &&
        !expired &&
        device?.online == true &&
        device?.identificationId == request.nonce &&
        device?.identificationAck == request.nonce;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          confirmed ? Icons.check_circle_outline : Icons.tv_outlined,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          device?.name ?? '디스플레이',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          confirmed
              ? 'TV가 응답했습니다. 아래 확인 번호가 보이는 TV가 맞나요?'
              : expired || state.hasError
              ? 'TV의 응답을 받지 못했습니다. TV 앱과 인터넷을 확인하고, 수업이 재생 중이면 종료한 뒤 다시 확인하세요.'
              : 'TV에 소리 없이 확인 화면을 표시하고 있습니다. TV 앱을 켜 두세요.',
        ),
        if (request != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              request.nonce.substring(request.nonce.length - 4),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
        const Text(
          '응답이 없으면 TV 앱을 최신 버전으로 업데이트해 주세요. 등록은 유지되므로 새로 추가할 필요가 없습니다.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !confirmed || saving.value
              ? null
              : () async {
                  saving.value = true;
                  try {
                    await ref
                        .read(firstClassControllerProvider.notifier)
                        .verified(deviceId);
                    if (context.mounted) onDone();
                  } finally {
                    if (context.mounted) saving.value = false;
                  }
                },
          child: const Text('이 TV가 맞아요'),
        ),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () => ref.read(provider.notifier).identify(),
          child: const Text('확인 화면 다시 보내기'),
        ),
      ],
    );
  }
}
