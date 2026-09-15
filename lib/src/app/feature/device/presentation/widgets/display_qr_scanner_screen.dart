import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/pairing_qr.dart';

class DisplayQrScannerScreen extends HookWidget {
  const DisplayQrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accepted = useRef(false);
    final invalid = useState(false);
    final scannerRevision = useState(0);
    final returningFromSettings = useRef(false);
    final openingSettings = useState(false);
    final supportsAppSettings =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    useOnAppLifecycleStateChange((previous, next) {
      if (next == AppLifecycleState.resumed && returningFromSettings.value) {
        returningFromSettings.value = false;
        scannerRevision.value++;
      }
    });
    Future<void> openSettings() async {
      if (openingSettings.value) return;
      openingSettings.value = true;
      returningFromSettings.value = true;
      try {
        await AppSettings.openAppSettings();
      } catch (_) {
        returningFromSettings.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '설정 화면을 열 수 없습니다. 기기 설정에서 클라우드보드의 카메라 권한을 확인해 주세요.',
              ),
            ),
          );
        }
      } finally {
        if (context.mounted) openingSettings.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('디스플레이 QR 스캔')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: MobileScanner(
                key: ValueKey(scannerRevision.value),
                // The widget owns its controller and camera lifecycle.
                onDetect: (capture) {
                  if (accepted.value) return;
                  for (final barcode in capture.barcodes) {
                    if (barcode.format != BarcodeFormat.qrCode) continue;
                    final code = pairingCodeFromQr(barcode.rawValue ?? '');
                    if (code != null) {
                      accepted.value = true;
                      Navigator.of(context).pop(code);
                      return;
                    }
                  }
                  invalid.value = true;
                },
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography_outlined, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          '카메라를 사용할 수 없습니다.\n설정에서 카메라 권한을 허용하거나\n연결 코드를 직접 입력해 주세요.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (supportsAppSettings) ...[
                          FilledButton.icon(
                            onPressed: openingSettings.value
                                ? null
                                : openSettings,
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('앱 설정 열기'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('코드 직접 입력'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    invalid.value
                        ? '클라우드보드 연결 QR을 비춰 주세요.'
                        : '연결할 디스플레이에 표시된 QR을 비춰 주세요.',
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('코드 직접 입력'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
