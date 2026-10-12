import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';

/// Shares the native launch artwork and canvas without a timed splash delay.
/// The mark stays centered when loading changes to a retry action.
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;
  static const markSize = 128.0;

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  WidgetsBinding? _deferredBinding;
  bool _requestedMark = false;

  @override
  void initState() {
    super.initState();
    _deferredBinding = WidgetsBinding.instance..deferFirstFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedMark) return;
    _requestedMark = true;
    // Framework frames and bootstrap initialization still proceed. Only the
    // native handoff waits for this local image, never for Firebase/network.
    precacheImage(
      SoftRhythmMark.imageProvider(context, AppStartupScreen.markSize),
      context,
      onError: (_, _) {},
    ).whenComplete(_releaseFirstFrame);
  }

  void _releaseFirstFrame() {
    _deferredBinding?.allowFirstFrame();
    _deferredBinding = null;
  }

  @override
  void dispose() {
    // A fast bootstrap can leave this route before decoding completes.
    _releaseFirstFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppColors.canvas,
    ),
    child: Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Center(
              child: Semantics(
                label: 'CloudBoard',
                image: true,
                child: const SoftRhythmMark(size: AppStartupScreen.markSize),
              ),
            ),
            Positioned(
              top:
                  constraints.maxHeight / 2 +
                  AppStartupScreen.markSize / 2 +
                  24,
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
                      child: widget.onRetry == null
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
                                  onPressed: widget.onRetry,
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
