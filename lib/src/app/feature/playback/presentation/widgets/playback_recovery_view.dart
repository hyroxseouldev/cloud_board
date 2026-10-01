import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Opaque recovery gate, also safe above a route's Scaffold or on a TV surface.
class PlaybackRecoveryView extends HookWidget {
  const PlaybackRecoveryView({
    super.key,
    this.displayMode = false,
    this.error,
    this.stackTrace,
    required this.onRetry,
  });

  final bool displayMode;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final showIndicator = useState(false);
    final slow = useState(false);
    useEffect(() {
      showIndicator.value = false;
      slow.value = false;
      if (error != null) return null;
      // Block input immediately, but avoid flashing a spinner on a fast resume.
      final reveal = Timer(const Duration(milliseconds: 180), () {
        showIndicator.value = true;
      });
      final hint = Timer(const Duration(seconds: 5), () {
        slow.value = true;
      });
      return () {
        reveal.cancel();
        hint.cancel();
      };
    }, [error]);

    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final rotation = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      if (showIndicator.value && error == null && !reduceMotion) {
        rotation.repeat();
      } else {
        rotation.stop();
      }
      return null;
    }, [showIndicator.value, error, reduceMotion]);
    final foreground = displayMode ? const Color(0xFFE4E1EE) : AppColors.muted;
    final actionColor = displayMode
        ? const Color(0xFFB7B0D4)
        : AppColors.accent;
    final style = TextStyle(
      inherit: false,
      fontFamily: 'Pretendard',
      fontSize: displayMode ? 22 : 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: foreground,
      decoration: TextDecoration.none,
    );
    final indicatorSize = displayMode ? 28.0 : 22.0;

    // A ColoredBox alone inherits Flutter's red/yellow fallback text above the
    // Navigator. Own the Material and text style instead of relying on a page.
    return Material(
      color: displayMode ? const Color(0xFF050505) : Colors.white,
      textStyle: style,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!displayMode)
              const Positioned(
                top: 20,
                left: 24,
                child: Text(
                  'CloudBoard',
                  style: TextStyle(
                    inherit: false,
                    fontFamily: 'Pretendard',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: displayMode ? 24 : 64,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: displayMode ? 520 : 360,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (error != null) ...[
                              Icon(
                                Icons.wifi_off_rounded,
                                size: indicatorSize,
                                color: actionColor,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '수업에 다시 연결하지 못했어요',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '네트워크를 확인하고 다시 시도해 주세요.',
                                textAlign: TextAlign.center,
                                style: style.copyWith(
                                  fontSize: displayMode ? 18 : 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Theme(
                                data:
                                    (displayMode
                                            ? ThemeData(
                                                brightness: Brightness.dark,
                                                fontFamily: 'Pretendard',
                                                colorScheme:
                                                    ColorScheme.fromSeed(
                                                      seedColor:
                                                          AppColors.accent,
                                                      brightness:
                                                          Brightness.dark,
                                                    ),
                                              )
                                            : Theme.of(context))
                                        .copyWith(
                                          textButtonTheme: TextButtonThemeData(
                                            style: TextButton.styleFrom(
                                              foregroundColor: actionColor,
                                              textStyle: style.copyWith(
                                                fontSize: displayMode ? 20 : 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              minimumSize: const Size(48, 48),
                                            ),
                                          ),
                                        ),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      autofocus: displayMode,
                                      onPressed: onRetry,
                                      child: const Text('다시 연결'),
                                    ),
                                    ErrorDetailsButton(
                                      error: error,
                                      stack: stackTrace,
                                      action: 'playback.recover',
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (showIndicator.value) ...[
                              ExcludeSemantics(
                                child: SizedBox.square(
                                  dimension: indicatorSize,
                                  child: reduceMotion
                                      ? Icon(
                                          Icons.sync_rounded,
                                          size: indicatorSize,
                                          color: AppColors.accent,
                                        )
                                      : RotationTransition(
                                          turns: rotation,
                                          // A constant open ring stays visible at
                                          // this small size. It is not progress;
                                          // semantics come from the status label.
                                          child:
                                              const CircularProgressIndicator(
                                                value: .75,
                                                strokeWidth: 2,
                                                strokeCap: StrokeCap.round,
                                                color: AppColors.accent,
                                              ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '수업 동기화 중',
                                textAlign: TextAlign.center,
                              ),
                              if (slow.value) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '연결을 확인하고 있어요. 잠시만 기다려 주세요.',
                                  textAlign: TextAlign.center,
                                  style: style.copyWith(
                                    fontSize: displayMode ? 16 : 12,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
