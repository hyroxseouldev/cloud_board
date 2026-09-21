import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_style.dart';

/// Bounds the whole management page, including its app bar, FAB and mini player.
/// Keep this tree stable when switching to full-screen playback so the nested
/// navigator and the active session are not recreated by a layout change.
class WebPageFrame extends StatelessWidget {
  const WebPageFrame({super.key, required this.child, this.fullWidth = false});

  final Widget child;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = fullWidth
            ? constraints.maxWidth
            : math.min(constraints.maxWidth, AppStyle.webPageMaxWidth);
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: Size(width, constraints.maxHeight)),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
