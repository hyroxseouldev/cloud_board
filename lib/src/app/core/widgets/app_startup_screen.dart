import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';

/// Matches the native launch screen without an image decoding frame or delay.
/// The mark stays centered when loading changes to a retry action.
class AppStartupScreen extends StatelessWidget {
  const AppStartupScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;
  static const markSize = 128.0;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
    ),
    child: Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Center(
              child: Semantics(
                label: 'CloudBoard',
                image: true,
                child: const CustomPaint(
                  size: Size.square(markSize),
                  painter: StartupMarkPainter(),
                ),
              ),
            ),
            Positioned(
              top: constraints.maxHeight / 2 + markSize / 2 + 24,
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: onRetry == null
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: '앱 준비 중',
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '앱을 준비하지 못했습니다.\n연결을 확인하고 다시 시도해 주세요.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  autofocus: true,
                                  onPressed: onRetry,
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Existing app-icon geometry from
/// docs/play-store/ko-KR/assets/branding/app-icon-draft.svg.
/// Also exported by tool/generate_splash_assets_test.dart for native resources.
class StartupMarkPainter extends CustomPainter {
  const StartupMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 512, size.height / 512);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 512, 512),
      Paint()..color = AppColors.accent,
    );
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(106, 123, 300, 214),
        const Radius.circular(30),
      ),
      stroke,
    );
    stroke.strokeWidth = 20;
    canvas.drawPath(
      Path()
        ..moveTo(130, 236)
        ..lineTo(193, 236)
        ..lineTo(220, 189)
        ..lineTo(259, 276)
        ..lineTo(293, 224)
        ..lineTo(382, 224)
        ..moveTo(256, 341)
        ..lineTo(256, 383)
        ..moveTo(208, 385)
        ..lineTo(304, 385),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(StartupMarkPainter oldDelegate) => false;
}
