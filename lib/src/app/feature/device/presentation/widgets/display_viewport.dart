import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';

class DisplayViewport extends StatelessWidget {
  const DisplayViewport({
    super.key,
    required this.preferences,
    required this.child,
  });
  final DisplayPreferences preferences;
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: ClipRect(
      child: preferences.enabled && preferences.cover
          ? SizedBox.expand(child: child)
          : Center(
              child: AspectRatio(aspectRatio: 16 / 9, child: child),
            ),
    ),
  );
}
