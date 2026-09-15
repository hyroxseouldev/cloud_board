import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/pairing_qr.dart';

class DisplayPairingCard extends StatelessWidget {
  const DisplayPairingCard({
    super.key,
    required this.ticket,
    required this.now,
    required this.onRefresh,
  });
  final DevicePairing ticket;
  final DateTime now;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final remaining = ((ticket.expiresAtMs - now.millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 600);
    final expired = remaining == 0;
    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '컨트롤러 연결 코드',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        expired
                            ? '만료됨'
                            : '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      IconButton(
                        tooltip: '새 연결 코드',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!expired)
                    QrImageView(
                      data: pairingQrPayload(ticket.code),
                      size: 200,
                      backgroundColor: Colors.white,
                      semanticsLabel: '디스플레이 연결 QR 코드',
                    )
                  else
                    const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          '코드가 만료되었습니다.\n새 연결 코드를 만들어 주세요.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    expired ? '------' : ticket.code,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '휴대폰 / 태블릿에서 디스플레이 설정을 열고\nQR을 스캔하거나 연결 코드를 입력해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
