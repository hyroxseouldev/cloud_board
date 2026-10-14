import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';

enum AudienceLogoScene { standby, countdown, classContent }

/// An audience-only footer outside artwork zoom, crop, timer and user text.
/// Keep this frame and its first child mounted when a policy changes. A known
/// scope reserves the same space with the logo shown or hidden, so paid toggles
/// do not move the artwork or restart its player.
class AudienceLogoFrame extends StatelessWidget {
  const AudienceLogoFrame({
    super.key,
    required this.branding,
    required this.scene,
    required this.child,
    this.preferences = const DisplayPreferences(),
    this.backgroundColor = Colors.black,
  });

  final AudienceBranding? branding;
  final AudienceLogoScene scene;
  final Widget child;
  final DisplayPreferences preferences;
  final Color backgroundColor;

  bool get applies =>
      branding != null &&
      (scene == AudienceLogoScene.standby || branding!.includesClassScreens);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(
        constraints.maxWidth / 1920,
        constraints.maxHeight / 1080,
      );
      final compact = scene == AudienceLogoScene.classContent;
      final badgeHeight = ((compact ? 48 : 64) * scale).clamp(28.0, 128.0);
      final badgeWidth = ((compact ? 240 : 320) * scale).clamp(140.0, 640.0);
      final system = MediaQuery.paddingOf(context);
      final inset = preferences.enabled
          ? preferences.safeInset.clamp(0.0, .2)
          : 0.0;
      final horizontal = math.max(
        constraints.maxWidth * math.max(.025, inset),
        math.max(system.left, system.right),
      );
      final bottom = math.max(
        constraints.maxHeight * math.max(.025, inset),
        system.bottom,
      );
      final gap = (12 * scale).clamp(6.0, 24.0);
      return ColoredBox(
        color: backgroundColor,
        child: Column(
          children: [
            Expanded(child: child),
            if (applies)
              Padding(
                key: const ValueKey('audience-logo-reserved-area'),
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  gap,
                  horizontal,
                  bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: badgeHeight,
                  child: branding!.showCloudBoardLogo
                      ? Center(
                          child: Semantics(
                            label: AppBrand.name,
                            image: true,
                            child: ExcludeSemantics(
                              child: SizedBox(
                                key: const ValueKey('audience-cloudboard-logo'),
                                width: badgeWidth,
                                height: badgeHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F5EF),
                                    borderRadius: BorderRadius.circular(
                                      8 * math.max(scale, .5),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: badgeHeight * .18,
                                      vertical: badgeHeight * .12,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SoftRhythmMark(
                                            size: compact ? 28 : 40,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            AppBrand.name,
                                            style: TextStyle(
                                              color: const Color(0xFF2B332E),
                                              fontFamily: 'Pretendard',
                                              fontSize: compact ? 24 : 32,
                                              height: 1,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      );
    },
  );
}
