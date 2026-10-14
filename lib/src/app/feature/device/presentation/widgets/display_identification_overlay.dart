import 'dart:math' as math;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// System-owned identification surface. It can sit above a route's Scaffold,
/// so it owns its Material/text boundary instead of inheriting route fallback
/// text. This never changes the underlying class or center-content theme.
class DisplayIdentificationOverlay extends StatelessWidget {
  const DisplayIdentificationOverlay({
    super.key,
    required this.deviceName,
    required this.code,
  });

  final String deviceName;
  final String code;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('display-identification-surface'),
    color: AppColors.canvas,
    textStyle: const TextStyle(
      inherit: false,
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0,
      color: AppColors.ink,
      decoration: TextDecoration.none,
    ),
    child: LayoutBuilder(
      builder: (context, viewport) {
        final short = viewport.maxHeight < 480;
        final large = viewport.maxWidth >= 2560;
        final desktop = viewport.maxWidth >= 1600;
        final narrow = viewport.maxWidth < 1000;
        final nameSize = short
            ? 24.0
            : large
            ? 72.0
            : desktop
            ? 44.0
            : narrow
            ? 28.0
            : 36.0;
        final titleSize = short
            ? 16.0
            : large
            ? 36.0
            : desktop
            ? 24.0
            : narrow
            ? 18.0
            : 20.0;
        final bodySize = short
            ? 14.0
            : large
            ? 36.0
            : desktop
            ? 22.0
            : narrow
            ? 16.0
            : 20.0;
        final numberSize = short
            ? 76.0
            : large
            ? 384.0
            : desktop
            ? 192.0
            : narrow
            ? 112.0
            : 160.0;
        final gap = short
            ? 10.0
            : desktop || large
            ? 28.0
            : 20.0;
        final maxWidth = large
            ? 1200.0
            : desktop
            ? 960.0
            : 800.0;
        return SafeArea(
          minimum: EdgeInsets.symmetric(
            horizontal: (viewport.maxWidth * .05).clamp(24.0, 192.0),
            vertical: (viewport.maxHeight * .05).clamp(24.0, 108.0),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, space) {
                  final width = math.min(space.maxWidth, maxWidth);
                  return SizedBox(
                    key: const ValueKey('display-identification-content'),
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.tv_rounded,
                                size: titleSize + 8,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'TV 연결 확인',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        // Wrap full names first, then fit only an unusually long
                        // name into its own area. Never scale the whole screen.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                nameSize *
                                2.5 *
                                MediaQuery.textScalerOf(context)
                                    .scale(1)
                                    .clamp(1.0, 1.5),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: width,
                              child: Text(
                                deviceName,
                                key: const ValueKey(
                                  'display-identification-name',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: nameSize,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -nameSize * .01,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: gap),
                        Semantics(
                          label: '확인 번호 ${code.split('').join(' ')}',
                          child: ExcludeSemantics(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                code,
                                key: const ValueKey(
                                  'display-identification-code',
                                ),
                                // The code is already the largest element. Keep
                                // all four digits together at accessibility scale.
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: numberSize,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  letterSpacing: numberSize * .04,
                                  height: 1,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: gap),
                        Text(
                          '관리 기기에서 이 번호를 확인해 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: bodySize, height: 1.45),
                        ),
                        SizedBox(height: short ? 4 : 8),
                        Text(
                          '소리는 재생되지 않아요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: bodySize - 2,
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}
